import json
import plistlib
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

from apple_distribution import (
    APP_GROUP,
    RENEWAL_KEYCHAIN_GROUP,
    TARGET_BUNDLE_IDS,
    TEAM_ID,
    Profile,
    ValidationError,
)
from source_preparation import (
    native_distribution_for,
    prepare_ios_source_tree,
    projected_target_entitlements,
    sign_archive_bundle,
    unsigned_archive_command,
)


class SourcePreparationTests(unittest.TestCase):
    def make_source_fixture(self, root: Path) -> Path:
        (root / 'ios' / 'Flutter').mkdir(parents=True)
        (root / 'ios' / 'Runner').mkdir(parents=True)
        (root / 'ios' / 'NECore').mkdir(parents=True)
        (root / 'ios' / 'Runner' / 'Runner.entitlements').write_text(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<plist version="1.0"><dict>'
            '<key>keychain-access-groups</key><array><string>$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)</string></array>'
            '<key>com.apple.developer.networking.networkextension</key><array><string>packet-tunnel-provider</string></array>'
            '<key>com.apple.security.application-groups</key><array><string>group.$(APP_BUNDLE_ID)</string></array>'
            '</dict></plist>\n',
            encoding='utf-8',
        )
        (root / 'ios' / 'NECore' / 'NECore.entitlements').write_text(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<plist version="1.0"><dict>'
            '<key>com.apple.developer.networking.networkextension</key><array><string>packet-tunnel-provider</string></array>'
            '<key>com.apple.security.application-groups</key><array><string>group.$(APP_BUNDLE_ID)</string></array>'
            '</dict></plist>\n',
            encoding='utf-8',
        )
        for target_dir in ('Runner', 'NECore'):
            with (root / 'ios' / target_dir / 'Info.plist').open('wb') as stream:
                plistlib.dump({
                    'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
                    'ZolNitRenewalKeychainAccessGroup': '$(ZOLNIT_RENEWAL_KEYCHAIN_GROUP)',
                    'ZolNitDistribution': '$(ZOLNIT_NATIVE_DISTRIBUTION)',
                    'ZolNitRenewalWhileLocked': False,
                }, stream)
        return root

    def test_prepare_ios_source_tree_direct_and_app_store_modes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = self.make_source_fixture(Path(temporary))
            res_direct = prepare_ios_source_tree(repo, 'release-testing')
            self.assertEqual(res_direct['native_distribution'], 'direct')
            env_json = json.loads((repo / 'env.json').read_text(encoding='utf-8'))
            self.assertEqual(env_json['ZOLNIT_DISTRIBUTION'], 'direct')
            xcconfig = (repo / 'ios' / 'Flutter' / 'GeneratedBundleConfig.xcconfig').read_text(encoding='utf-8')
            self.assertIn('ZOLNIT_NATIVE_DISTRIBUTION = direct', xcconfig)
            self.assertIn(f'ZOLNIT_RENEWAL_KEYCHAIN_GROUP = {RENEWAL_KEYCHAIN_GROUP}', xcconfig)

            res_store = prepare_ios_source_tree(repo, 'app-store-connect')
            self.assertEqual(res_store['native_distribution'], 'apple-app-store')
            env_json2 = json.loads((repo / 'env.json').read_text(encoding='utf-8'))
            self.assertEqual(env_json2['ZOLNIT_DISTRIBUTION'], 'apple-app-store')

            for rel in ('Runner/Runner.entitlements', 'NECore/NECore.entitlements'):
                root = ET.parse(repo / 'ios' / rel).getroot()
                strings = [el.text for el in root.findall('.//string')]
                self.assertEqual(strings.count('$(ZOLNIT_RENEWAL_KEYCHAIN_GROUP)'), 1)

            for rel in ('Runner/Info.plist', 'NECore/Info.plist'):
                info = plistlib.loads((repo / 'ios' / rel).read_bytes())
                self.assertIs(info['ZolNitRenewalWhileLocked'], True)
                self.assertEqual(info['ZolNitRenewalKeychainAccessGroup'], '$(ZOLNIT_RENEWAL_KEYCHAIN_GROUP)')
                self.assertEqual(info['ZolNitDistribution'], '$(ZOLNIT_NATIVE_DISTRIBUTION)')

    def test_unsigned_archive_command_disables_automatic_signing(self) -> None:
        cmd = unsigned_archive_command(Path('/tmp/src/ios/Runner.xcworkspace'), Path('/tmp/out/Runner.xcarchive'), Path('/tmp/dd'))
        self.assertIn('CODE_SIGNING_ALLOWED=NO', cmd)
        self.assertIn('CODE_SIGNING_REQUIRED=NO', cmd)
        self.assertIn('CODE_SIGN_IDENTITY=', cmd)
        self.assertIn('DEVELOPMENT_TEAM=', cmd)

    def test_projected_entitlements_and_manual_archive_signing(self) -> None:
        app_store_ent = projected_target_entitlements('app', 'app-store-connect')
        self.assertIs(app_store_ent['beta-reports-active'], True)
        self.assertIn(RENEWAL_KEYCHAIN_GROUP, app_store_ent['keychain-access-groups'])

        adhoc_ent = projected_target_entitlements('app', 'release-testing')
        self.assertNotIn('beta-reports-active', adhoc_ent)
        ne_ent = projected_target_entitlements('necore', 'release-testing')
        self.assertEqual(ne_ent['keychain-access-groups'], [RENEWAL_KEYCHAIN_GROUP])

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / 'Runner.xcarchive'
            app_dir = archive / 'Products' / 'Applications' / 'Runner.app'
            ne_dir = app_dir / 'PlugIns' / 'NECore.appex'
            wid_dir = app_dir / 'PlugIns' / 'Widget.appex'
            fw_dir = app_dir / 'Frameworks' / 'Pods_Runner.framework'
            ne_dir.mkdir(parents=True)
            wid_dir.mkdir(parents=True)
            fw_dir.mkdir(parents=True)
            with (archive / 'Info.plist').open('wb') as stream:
                plistlib.dump({'ArchiveVersion': 2, 'Name': 'Runner'}, stream)
            for bdir, bid in ((app_dir, TARGET_BUNDLE_IDS['app']), (ne_dir, TARGET_BUNDLE_IDS['necore'])):
                with (bdir / 'Info.plist').open('wb') as stream:
                    plistlib.dump({
                        'CFBundleIdentifier': bid,
                        'ZolNitDistribution': native_distribution_for('release-testing'),
                        'ZolNitRenewalKeychainAccessGroup': RENEWAL_KEYCHAIN_GROUP,
                        'ZolNitRenewalWhileLocked': True,
                    }, stream)
            profiles: dict[str, Profile] = {}
            now = datetime.now(timezone.utc)
            for target, bid in TARGET_BUNDLE_IDS.items():
                p_path = root / f'{target}.mobileprovision'
                p_path.write_bytes(f'profile-{target}'.encode('utf-8'))
                profiles[target] = Profile(target, p_path, f'{target}-uuid', TEAM_ID, bid, APP_GROUP, now + timedelta(days=10), 'a' * 64)

            def fake_runner(command):
                cmd = list(command)
                if cmd[:3] == ['codesign', '-d', '--entitlements']:
                    is_ne = cmd[-1].endswith('NECore.appex')
                    ent = projected_target_entitlements('necore' if is_ne else 'app', 'release-testing')
                    return subprocess.CompletedProcess(cmd, 0, plistlib.dumps(ent).decode('utf-8'), '')
                return subprocess.CompletedProcess(cmd, 0, '', '')

            cmds = sign_archive_bundle(
                archive, 'release-testing', profiles, '0123456789ABCDEF0123456789ABCDEF01234567',
                runner=fake_runner, keychain_path=root / 'temp.keychain-db',
            )
            self.assertEqual(len(cmds), 5)
            self.assertTrue((app_dir / 'embedded.mobileprovision').is_file())
            self.assertTrue((ne_dir / 'embedded.mobileprovision').is_file())
            self.assertTrue((wid_dir / 'embedded.mobileprovision').is_file())

            with self.assertRaises(ValidationError):
                bad_info = app_dir / 'Info.plist'
                data = plistlib.loads(bad_info.read_bytes())
                data['ZolNitDistribution'] = 'apple-app-store'
                bad_info.write_bytes(plistlib.dumps(data))
                sign_archive_bundle(archive, 'release-testing', profiles, '0123456789ABCDEF0123456789ABCDEF01234567', runner=fake_runner)


if __name__ == '__main__':
    unittest.main()
