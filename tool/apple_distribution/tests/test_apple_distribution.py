import hashlib
import os
import plistlib
import stat
import subprocess
import tempfile
import unittest
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from apple_distribution import (
    APPLE_PROVISIONING_SIGNER,
    APPLE_ROOT_KEYCHAIN,
    APP_GROUP,
    NETWORK_EXTENSION,
    RENEWAL_KEYCHAIN_GROUP,
    TARGET_APPEX_NAMES,
    TEAM_ID,
    TARGET_BUNDLE_IDS,
    ValidationError,
    command_plan,
    embedded_profile_path,
    export_options,
    exported_app,
    extract_plist_xml,
    main,
    read_profile,
    validate_app_renewal_contract,
    validate_archive_bundle,
    validate_source,
    verification_commands,
)

SAMPLE_SHA = '2a2779b9c385340628d65f52526f9324bdc69b9f'
FUTURE_SHA = '8f3e4a91b20c7d6514ef320987654321fedcba98'


class AppleDistributionTests(unittest.TestCase):
    def profile_payload(self, target: str, distribution: str = 'release-testing', **changes: object) -> dict[str, object]:
        bundle = TARGET_BUNDLE_IDS[target]
        now = datetime.now(timezone.utc)
        entitlements: dict[str, object] = {
            'application-identifier': f'{TEAM_ID}.{bundle}',
            'com.apple.developer.team-identifier': TEAM_ID,
            'com.apple.security.application-groups': [APP_GROUP],
            'com.apple.developer.networking.networkextension': [NETWORK_EXTENSION],
            'keychain-access-groups': [f'{TEAM_ID}.*'],
            'get-task-allow': False,
        }
        if distribution == 'app-store-connect' and target == 'app':
            entitlements['beta-reports-active'] = True
        payload: dict[str, object] = {
            'UUID': f'{target}-synthetic',
            'TeamIdentifier': [TEAM_ID],
            'CreationDate': now - timedelta(days=1),
            'ExpirationDate': now + timedelta(days=30),
            'Entitlements': entitlements,
        }
        if distribution == 'release-testing':
            payload['ProvisionedDevices'] = ['00008110-0011223344556677']
        payload.update(changes)
        return payload

    def profile(
        self,
        directory: Path,
        target: str,
        *,
        distribution: str = 'release-testing',
        suffix: str = '.plist',
        **changes: object,
    ) -> Path:
        payload = self.profile_payload(target, distribution=distribution, **changes)
        path = directory / f'{target}{suffix}'
        with path.open('wb') as stream:
            plistlib.dump(payload, stream)
        return path

    def make_archive(self, directory: Path, name: str = 'Runner.xcarchive', *, signed: bool = True, native_dist: str = 'apple-app-store') -> Path:
        archive = directory / name
        app_dir = archive / 'Products' / 'Applications' / 'Runner.app'
        ne_dir = app_dir / 'PlugIns' / 'NECore.appex'
        wid_dir = app_dir / 'PlugIns' / 'Widget.appex'
        ne_dir.mkdir(parents=True)
        wid_dir.mkdir(parents=True)
        if signed:
            (app_dir / '_CodeSignature').mkdir(parents=True)
            (app_dir / 'embedded.mobileprovision').write_bytes(b'signed')
        for bdir, bid in ((app_dir, TARGET_BUNDLE_IDS['app']), (ne_dir, TARGET_BUNDLE_IDS['necore'])):
            with (bdir / 'Info.plist').open('wb') as stream:
                plistlib.dump({
                    'CFBundleIdentifier': bid,
                    'ZolNitDistribution': native_dist,
                    'ZolNitRenewalKeychainAccessGroup': RENEWAL_KEYCHAIN_GROUP,
                    'ZolNitRenewalWhileLocked': True,
                }, stream)
        with (archive / 'Info.plist').open('wb') as stream:
            plistlib.dump({'ArchiveVersion': 2, 'Name': 'Runner'}, stream)
        return archive

    def test_export_options_cover_all_targets(self) -> None:
        profiles = {target: type('P', (), {'uuid': f'{target}-uuid'})() for target in TARGET_BUNDLE_IDS}
        options = export_options('release-testing', profiles)
        self.assertEqual(options['method'], 'release-testing')
        self.assertEqual(set(options['provisioningProfiles']), set(TARGET_BUNDLE_IDS.values()))

    def test_bad_bundle_id_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            path = self.profile(directory, 'app', Entitlements={
                'application-identifier': f'{TEAM_ID}.com.wrong.app',
                'com.apple.developer.team-identifier': TEAM_ID,
                'com.apple.security.application-groups': [APP_GROUP],
                'com.apple.developer.networking.networkextension': [NETWORK_EXTENSION],
                'keychain-access-groups': [f'{TEAM_ID}.*'],
                'get-task-allow': False,
            })
            with self.assertRaises(ValidationError):
                read_profile('app', path, None, lambda _: subprocess.CompletedProcess([], 0, '', ''))

    def test_commands_are_argv_lists(self) -> None:
        commands = command_plan(Path('/tmp/a.xcarchive'), Path('/tmp/options.plist'), Path('/tmp/export'))
        self.assertEqual(commands[0][:2], ['xcodebuild', '-exportArchive'])
        self.assertTrue(all(isinstance(part, str) for part in commands[0]))

    def test_default_preflight_never_exports(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            profiles = {target: self.profile(directory, target) for target in TARGET_BUNDLE_IDS}
            calls = []

            def fake_runner(command):
                calls.append(command)
                if command[:3] == ['git', '-C', str(directory)] and 'rev-parse' in command:
                    return subprocess.CompletedProcess(command, 0, SAMPLE_SHA + '\n', '')
                return subprocess.CompletedProcess(command, 0, '', '')

            result = main([
                '--repo', str(directory), '--app-profile', str(profiles['app']),
                '--necore-profile', str(profiles['necore']), '--widget-profile', str(profiles['widget']),
            ], runner=fake_runner)
            self.assertEqual(result, 0)
            self.assertFalse(any(command[:2] == ['xcodebuild', '-exportArchive'] for command in calls))

    def test_execute_requires_explicit_team(self) -> None:
        self.assertEqual(main(['--execute']), 2)

    def test_xcarchive_must_be_valid_directory_bundle_not_regular_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            fake_file = directory / 'FakeFile.xcarchive'
            fake_file.write_text('not a bundle', encoding='utf-8')
            with self.assertRaisesRegex(ValidationError, 'directory'):
                validate_archive_bundle(fake_file)

            incomplete_dir = directory / 'Incomplete.xcarchive'
            incomplete_dir.mkdir()
            with self.assertRaisesRegex(ValidationError, 'valid Xcode archive bundle'):
                validate_archive_bundle(incomplete_dir)

            valid_archive = self.make_archive(directory)
            validate_archive_bundle(valid_archive)

    def test_appex_paths_preserve_exact_case(self) -> None:
        app_path = Path('/tmp/Export/Payload/Runner.app')
        self.assertEqual(
            embedded_profile_path(app_path, 'necore'),
            Path('/tmp/Export/Payload/Runner.app/PlugIns/NECore.appex/embedded.mobileprovision'),
        )
        self.assertEqual(
            embedded_profile_path(app_path, 'widget'),
            Path('/tmp/Export/Payload/Runner.app/PlugIns/Widget.appex/embedded.mobileprovision'),
        )
        self.assertEqual(TARGET_APPEX_NAMES['necore'], 'NECore.appex')
        self.assertEqual(TARGET_APPEX_NAMES['widget'], 'Widget.appex')
        cmds = verification_commands(app_path, {'app': None, 'necore': None, 'widget': None})
        self.assertEqual(cmds, [['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app_path)]])

    def test_execute_rejects_raw_plist_and_requires_cms_verification_and_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            raw_plist = self.profile(directory, 'app', suffix='.plist')
            raw_digest = hashlib.sha256(raw_plist.read_bytes()).hexdigest()
            with self.assertRaisesRegex(ValidationError, 'raw .plist'):
                read_profile(
                    'app', raw_plist, raw_digest,
                    lambda cmd: subprocess.CompletedProcess(cmd, 0, '', ''),
                    execute=True, require_trusted_hash=True,
                )

            signed_profile = self.profile(directory, 'app', suffix='.mobileprovision')
            signed_bytes = signed_profile.read_bytes()
            signed_digest = hashlib.sha256(signed_bytes).hexdigest()

            with self.assertRaisesRegex(ValidationError, 'requires an explicit --profile-sha256'):
                read_profile(
                    'app', signed_profile, None,
                    lambda cmd: subprocess.CompletedProcess(cmd, 0, '', ''),
                    execute=True, require_trusted_hash=True,
                )

            def untrusted_signer_runner(command):
                self.assertNotEqual(command[:2], ['security', 'cms'])
                self.assertNotIn('-noverify', command)
                if command[:3] == ['security', 'find-certificate', '-a']:
                    return subprocess.CompletedProcess(command, 0, '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n', '')
                if command[:3] == ['openssl', 'cms', '-verify']:
                    signer_idx = command.index('-signer') + 1
                    Path(command[signer_idx]).write_text('CERT', encoding='utf-8')
                    return subprocess.CompletedProcess(command, 0, signed_bytes.decode('utf-8'), '')
                if command[:2] == ['openssl', 'x509']:
                    return subprocess.CompletedProcess(command, 0, 'subject=CN=SelfSigned Fake\nissuer=CN=SelfSigned Fake\n', '')
                return subprocess.CompletedProcess(command, 0, '', '')

            with self.assertRaisesRegex(ValidationError, 'unexpected provisioning profile signer'):
                read_profile(
                    'app', signed_profile, signed_digest, untrusted_signer_runner,
                    execute=True, require_trusted_hash=True,
                )

            def untrusted_chain_runner(command):
                self.assertNotEqual(command[:2], ['security', 'cms'])
                self.assertNotIn('-noverify', command)
                if command[:3] == ['security', 'find-certificate', '-a']:
                    return subprocess.CompletedProcess(command, 0, '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n', '')
                if command[:3] == ['openssl', 'cms', '-verify']:
                    return subprocess.CompletedProcess(command, 1, '', 'Verification failure')
                return subprocess.CompletedProcess(command, 0, '', '')

            with self.assertRaisesRegex(ValidationError, 'CMS chain verification failed'):
                read_profile(
                    'app', signed_profile, signed_digest, untrusted_chain_runner,
                    execute=True, require_trusted_hash=True,
                )

    def test_preflight_binary_profile_uses_openssl_cms_without_security_cms_or_leading_header_crash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            binary_profile = self.profile(directory, 'app', suffix='.mobileprovision')
            raw_plist_text = binary_profile.read_text(encoding='utf-8')
            header_prefixed_output = 'SMIME: \tlevel=1.1; type=signedData;\n' + raw_plist_text
            parsed_bytes = extract_plist_xml(header_prefixed_output)
            self.assertEqual(plistlib.loads(parsed_bytes)['UUID'], 'app-synthetic')

            calls: list[list[str]] = []

            def cms_runner(command):
                cmd = list(command)
                calls.append(cmd)
                self.assertNotEqual(cmd[:2], ['security', 'cms'])
                self.assertNotIn('-noverify', cmd)
                if cmd[:3] == ['security', 'find-certificate', '-a']:
                    return subprocess.CompletedProcess(cmd, 0, '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n', '')
                if cmd[:3] == ['openssl', 'cms', '-verify']:
                    signer_path = Path(cmd[cmd.index('-signer') + 1])
                    signer_path.write_text('CERT', encoding='utf-8')
                    return subprocess.CompletedProcess(cmd, 0, header_prefixed_output, '')
                if cmd[:2] == ['openssl', 'x509']:
                    return subprocess.CompletedProcess(
                        cmd, 0,
                        f'subject=CN={APPLE_PROVISIONING_SIGNER}, O=Apple Inc.\nissuer=CN=Apple Worldwide Developer Relations Certification Authority, O=Apple Inc.\n',
                        '',
                    )
                return subprocess.CompletedProcess(cmd, 0, '', '')

            prof = read_profile('app', binary_profile, None, cms_runner, distribution='release-testing', execute=False)
            self.assertEqual(prof.uuid, 'app-synthetic')
            self.assertFalse(any(c[:2] == ['security', 'cms'] for c in calls))

    def test_profile_distribution_type_entitlements_and_dates_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            noop = lambda cmd: subprocess.CompletedProcess(cmd, 0, '', '')

            debug_ent = self.profile_payload('app')['Entitlements'].copy()
            debug_ent['get-task-allow'] = True
            p_debug = self.profile(directory, 'app', Entitlements=debug_ent)
            with self.assertRaisesRegex(ValidationError, 'get-task-allow'):
                read_profile('app', p_debug, None, noop, distribution='release-testing')

            no_ne_ent = self.profile_payload('necore')['Entitlements'].copy()
            no_ne_ent['com.apple.developer.networking.networkextension'] = []
            p_no_ne = self.profile(directory, 'necore', Entitlements=no_ne_ent)
            with self.assertRaisesRegex(ValidationError, NETWORK_EXTENSION):
                read_profile('necore', p_no_ne, None, noop, distribution='release-testing')

            p_adhoc_no_devices = self.profile(directory, 'app', ProvisionedDevices=[])
            with self.assertRaisesRegex(ValidationError, 'ProvisionedDevices'):
                read_profile('app', p_adhoc_no_devices, None, noop, distribution='release-testing')

            p_enterprise = self.profile(directory, 'app', ProvisionsAllDevices=True)
            with self.assertRaisesRegex(ValidationError, 'ProvisionsAllDevices'):
                read_profile('app', p_enterprise, None, noop, distribution='release-testing')

            p_appstore_with_devices = self.profile(
                directory, 'app', distribution='app-store-connect',
                ProvisionedDevices=['00008110-0011223344556677'],
            )
            with self.assertRaisesRegex(ValidationError, 'must not contain ProvisionedDevices'):
                read_profile('app', p_appstore_with_devices, None, noop, distribution='app-store-connect')

            no_beta_ent = self.profile_payload('app', distribution='app-store-connect')['Entitlements'].copy()
            del no_beta_ent['beta-reports-active']
            p_appstore_no_beta = self.profile(
                directory, 'app', distribution='app-store-connect',
                Entitlements=no_beta_ent,
            )
            with self.assertRaisesRegex(ValidationError, 'beta-reports-active'):
                read_profile('app', p_appstore_no_beta, None, noop, distribution='app-store-connect')

            p_future = self.profile(
                directory, 'widget',
                CreationDate=datetime.now(timezone.utc) + timedelta(hours=2),
            )
            with self.assertRaisesRegex(ValidationError, 'CreationDate is in the future'):
                read_profile('widget', p_future, None, noop, distribution='release-testing')

    def test_validate_source_accepts_future_stable_tags_and_rejects_arbitrary_refs(self) -> None:
        repo = Path('/tmp/repo')

        def tag_runner(command):
            if command == ['git', '-C', str(repo), 'rev-parse', '--verify', 'refs/tags/v1.2.0^{commit}']:
                return subprocess.CompletedProcess(command, 0, FUTURE_SHA + '\n', '')
            if command == ['git', '-C', str(repo), 'rev-parse', 'HEAD']:
                return subprocess.CompletedProcess(command, 0, FUTURE_SHA + '\n', '')
            return subprocess.CompletedProcess(command, 1, '', 'missing')

        tag, sha = validate_source(repo, None, 'v1.2.0', tag_runner)
        self.assertEqual((tag, sha), ('v1.2.0', FUTURE_SHA))

        with self.assertRaisesRegex(ValidationError, 'stable release tag'):
            validate_source(repo, None, 'v1.2.0-pre.1', tag_runner)

        with self.assertRaisesRegex(ValidationError, 'stable release tag'):
            validate_source(repo, None, 'main', tag_runner)

        with self.assertRaisesRegex(ValidationError, 'does not match stable tag'):
            validate_source(repo, SAMPLE_SHA, 'v1.2.0', tag_runner)

    def test_exported_app_rejects_symlinks_multiple_apps_and_stale_nested_apps(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            stale_dir = root / 'stale_case'
            (stale_dir / 'old' / 'Nested.app').mkdir(parents=True)
            with self.assertRaisesRegex(ValidationError, 'export did not produce'):
                exported_app(stale_dir, root / 'tmp1')

            multi_dir = root / 'multi_case'
            (multi_dir / 'One.app').mkdir(parents=True)
            (multi_dir / 'Two.app').mkdir(parents=True)
            with self.assertRaisesRegex(ValidationError, 'expected exactly one'):
                exported_app(multi_dir, root / 'tmp2')

            symlink_ipa_dir = root / 'symlink_case'
            symlink_ipa_dir.mkdir()
            ipa_path = symlink_ipa_dir / 'Runner.ipa'
            with zipfile.ZipFile(ipa_path, 'w') as zf:
                info = zipfile.ZipInfo('Payload/Runner.app/evil_link')
                info.external_attr = (stat.S_IFLNK | 0o777) << 16
                zf.writestr(info, '/etc/passwd')
            with self.assertRaisesRegex(ValidationError, 'symbolic link'):
                exported_app(symlink_ipa_dir, root / 'tmp3')

            symbols_ipa_dir = root / 'symbols_ok'
            symbols_ipa_dir.mkdir()
            symbols_ipa = symbols_ipa_dir / 'Runner.ipa'
            with zipfile.ZipFile(symbols_ipa, 'w') as zf:
                exec_info = zipfile.ZipInfo('Payload/Runner.app/Runner')
                exec_info.external_attr = (stat.S_IFREG | 0o755) << 16
                zf.writestr(exec_info, b'\xcf\xfa\xed\xfe')
                plist_info = zipfile.ZipInfo('Payload/Runner.app/Info.plist')
                plist_info.external_attr = (stat.S_IFREG | 0o644) << 16
                zf.writestr(plist_info, b'plist')
                sym_dir = zipfile.ZipInfo('Symbols/')
                sym_dir.external_attr = (stat.S_IFDIR | 0o755) << 16
                zf.writestr(sym_dir, b'')
                sym_file = zipfile.ZipInfo('Symbols/F477A6D5-CC5C-3299-9420-0323BB47584F.symbols')
                sym_file.external_attr = (stat.S_IFREG | 0o644) << 16
                zf.writestr(sym_file, b'symdata')
            extracted_app = exported_app(symbols_ipa_dir, root / 'tmp4')
            self.assertEqual(extracted_app.name, 'Runner.app')
            self.assertTrue(os.access(extracted_app / 'Runner', os.X_OK))
            self.assertFalse(os.access(extracted_app / 'Info.plist', os.X_OK))

            for idx, (bad_entry, is_symlink) in enumerate([
                ('EvilRoot/file.txt', False),
                ('Symbols/not-a-uuid.symbols', False),
                ('Symbols/nested/F477A6D5-CC5C-3299-9420-0323BB47584F.symbols', False),
                ('Symbols/../Payload/Runner.app/x', False),
                ('Symbols/F477A6D5-CC5C-3299-9420-0323BB47584F.symbols', True),
            ]):
                bad_dir = root / f'bad_sym_{idx}'
                bad_dir.mkdir()
                bad_ipa = bad_dir / 'Runner.ipa'
                with zipfile.ZipFile(bad_ipa, 'w') as zf:
                    zf.writestr('Payload/Runner.app/Info.plist', b'plist')
                    info = zipfile.ZipInfo(bad_entry)
                    if is_symlink:
                        info.external_attr = (stat.S_IFLNK | 0o777) << 16
                    else:
                        info.external_attr = (stat.S_IFREG | 0o644) << 16
                    zf.writestr(info, b'bad')
                with self.assertRaises(ValidationError):
                    exported_app(bad_dir, root / f'tmp_bad_{idx}')

    def test_renewal_keychain_and_while_locked_contracts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            noop = lambda cmd: subprocess.CompletedProcess(cmd, 0, '', '')
            no_kc_ent = self.profile_payload('necore')['Entitlements'].copy()
            no_kc_ent['keychain-access-groups'] = ['OTHERTEAM.*']
            p_bad_kc = self.profile(root, 'necore', Entitlements=no_kc_ent)
            with self.assertRaisesRegex(ValidationError, 'keychain-access-groups'):
                read_profile('necore', p_bad_kc, None, noop)

            bad_arch = self.make_archive(root, 'BadLocked.xcarchive')
            ne_info_path = bad_arch / 'Products' / 'Applications' / 'Runner.app' / 'PlugIns' / 'NECore.appex' / 'Info.plist'
            info_data = plistlib.loads(ne_info_path.read_bytes())
            info_data['ZolNitRenewalWhileLocked'] = False
            with ne_info_path.open('wb') as stream:
                plistlib.dump(info_data, stream)
            with self.assertRaisesRegex(ValidationError, 'ZolNitRenewalWhileLocked'):
                validate_archive_bundle(bad_arch)

            valid_arch = self.make_archive(root, 'Valid.xcarchive')
            app_dir = valid_arch / 'Products' / 'Applications' / 'Runner.app'

            def missing_ne_kc_runner(command):
                target_dir = Path(command[-1])
                is_ne = target_dir.name == 'NECore.appex'
                bid = TARGET_BUNDLE_IDS['necore'] if is_ne else TARGET_BUNDLE_IDS['app']
                ent = {
                    'application-identifier': f'{TEAM_ID}.{bid}',
                    'com.apple.developer.team-identifier': TEAM_ID,
                    'com.apple.security.application-groups': [APP_GROUP],
                    'com.apple.developer.networking.networkextension': [NETWORK_EXTENSION],
                    'keychain-access-groups': [] if is_ne else [RENEWAL_KEYCHAIN_GROUP],
                }
                return subprocess.CompletedProcess(command, 0, plistlib.dumps(ent).decode('utf-8'), '')

            with self.assertRaisesRegex(ValidationError, 'signed entitlements missing'):
                validate_app_renewal_contract(app_dir, missing_ne_kc_runner, check_signed_entitlements=True)

    def test_execute_rejects_unsigned_archive_without_signing_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.make_archive(root, 'Unsigned.xcarchive', signed=False, native_dist='direct')
            export_dir = root / 'export'
            profiles: dict[str, Path] = {}
            hashes: list[str] = []
            for target in TARGET_BUNDLE_IDS:
                p = self.profile(root, target, distribution='release-testing', suffix='.mobileprovision')
                digest = hashlib.sha256(p.read_bytes()).hexdigest()
                profiles[target] = p
                hashes.extend(['--profile-sha256', f'{target}={digest}'])

            def runner(command):
                cmd = list(command)
                if cmd[:3] == ['git', '-C', str(root)] and 'rev-parse' in cmd:
                    return subprocess.CompletedProcess(cmd, 0, FUTURE_SHA + '\n', '')
                if cmd[:3] == ['security', 'find-certificate', '-a']:
                    return subprocess.CompletedProcess(cmd, 0, '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n', '')
                if cmd[:3] == ['openssl', 'cms', '-verify']:
                    in_path = Path(cmd[cmd.index('-in') + 1])
                    signer_path = Path(cmd[cmd.index('-signer') + 1])
                    signer_path.write_text('CERT', encoding='utf-8')
                    return subprocess.CompletedProcess(cmd, 0, in_path.read_text(encoding='utf-8'), '')
                if cmd[:2] == ['openssl', 'x509']:
                    return subprocess.CompletedProcess(
                        cmd, 0,
                        f'subject=CN={APPLE_PROVISIONING_SIGNER}, O=Apple Inc.\nissuer=CN=Apple Worldwide Developer Relations Certification Authority, O=Apple Inc.\n',
                        '',
                    )
                return subprocess.CompletedProcess(cmd, 0, '', '')

            rc = main([
                '--execute', '--repo', str(root), '--source-tag', 'v1.2.0', '--source-sha', FUTURE_SHA,
                '--distribution', 'release-testing', '--team-id', TEAM_ID,
                '--archive-path', str(archive), '--export-path', str(export_dir),
                '--app-profile', str(profiles['app']), '--necore-profile', str(profiles['necore']),
                '--widget-profile', str(profiles['widget']), *hashes,
            ], runner=runner)
            self.assertEqual(rc, 2)

    def test_execute_end_to_end_with_verified_cms_and_ipa(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.make_archive(root)
            export_dir = root / 'export'
            profiles: dict[str, Path] = {}
            hashes: list[str] = []
            for target in TARGET_BUNDLE_IDS:
                p = self.profile(root, target, distribution='app-store-connect', suffix='.mobileprovision')
                digest = hashlib.sha256(p.read_bytes()).hexdigest()
                profiles[target] = p
                hashes.extend(['--profile-sha256', f'{target}={digest}'])

            asc_key = root / 'AuthKey_TESTKEY123.p8'
            asc_key.write_text('SYNTHETIC-TEST-ONLY-NOT-A-PRIVATE-KEY', encoding='utf-8')
            os.chmod(asc_key, 0o600)

            executed: list[list[str]] = []

            def runner(command):
                cmd = list(command)
                executed.append(cmd)
                self.assertNotEqual(cmd[:2], ['security', 'cms'])
                self.assertNotIn('-noverify', cmd)
                if cmd[:3] == ['git', '-C', str(root)] and 'rev-parse' in cmd:
                    return subprocess.CompletedProcess(cmd, 0, FUTURE_SHA + '\n', '')
                if cmd[:3] == ['security', 'find-certificate', '-a']:
                    self.assertIn(APPLE_ROOT_KEYCHAIN, cmd)
                    return subprocess.CompletedProcess(cmd, 0, '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n', '')
                if cmd[:3] == ['openssl', 'cms', '-verify']:
                    in_path = Path(cmd[cmd.index('-in') + 1])
                    signer_path = Path(cmd[cmd.index('-signer') + 1])
                    signer_path.write_text('CERT', encoding='utf-8')
                    return subprocess.CompletedProcess(cmd, 0, in_path.read_text(encoding='utf-8'), '')
                if cmd[:2] == ['openssl', 'x509']:
                    return subprocess.CompletedProcess(
                        cmd, 0,
                        f'subject=CN={APPLE_PROVISIONING_SIGNER}, O=Apple Inc.\nissuer=CN=Apple Worldwide Developer Relations Certification Authority, O=Apple Inc.\n',
                        '',
                    )
                if cmd[:2] == ['xcodebuild', '-exportArchive']:
                    ipa = export_dir / 'ZolNit.ipa'
                    app_info = plistlib.dumps({
                        'CFBundleIdentifier': TARGET_BUNDLE_IDS['app'],
                        'ZolNitDistribution': 'apple-app-store',
                        'ZolNitRenewalKeychainAccessGroup': RENEWAL_KEYCHAIN_GROUP,
                        'ZolNitRenewalWhileLocked': True,
                    })
                    ne_info = plistlib.dumps({
                        'CFBundleIdentifier': TARGET_BUNDLE_IDS['necore'],
                        'ZolNitDistribution': 'apple-app-store',
                        'ZolNitRenewalKeychainAccessGroup': RENEWAL_KEYCHAIN_GROUP,
                        'ZolNitRenewalWhileLocked': True,
                    })
                    with zipfile.ZipFile(ipa, 'w') as zf:
                        zf.writestr('Payload/Runner.app/Info.plist', app_info)
                        zf.writestr('Payload/Runner.app/PlugIns/NECore.appex/Info.plist', ne_info)
                        zf.writestr('Payload/Runner.app/embedded.mobileprovision', profiles['app'].read_bytes())
                        zf.writestr('Payload/Runner.app/PlugIns/NECore.appex/embedded.mobileprovision', profiles['necore'].read_bytes())
                        zf.writestr('Payload/Runner.app/PlugIns/Widget.appex/embedded.mobileprovision', profiles['widget'].read_bytes())
                    return subprocess.CompletedProcess(cmd, 0, '', '')
                if cmd[:3] == ['codesign', '-d', '--entitlements']:
                    is_ne = cmd[-1].endswith('NECore.appex')
                    bid = TARGET_BUNDLE_IDS['necore'] if is_ne else TARGET_BUNDLE_IDS['app']
                    ent = {
                        'application-identifier': f'{TEAM_ID}.{bid}',
                        'com.apple.developer.team-identifier': TEAM_ID,
                        'com.apple.security.application-groups': [APP_GROUP],
                        'com.apple.developer.networking.networkextension': [NETWORK_EXTENSION],
                        'keychain-access-groups': [f'{TEAM_ID}.{bid}', RENEWAL_KEYCHAIN_GROUP],
                    }
                    return subprocess.CompletedProcess(cmd, 0, plistlib.dumps(ent).decode('utf-8'), '')
                return subprocess.CompletedProcess(cmd, 0, '', '')

            rc = main([
                '--execute',
                '--repo', str(root),
                '--source-tag', 'v1.2.0',
                '--source-sha', FUTURE_SHA,
                '--distribution', 'app-store-connect',
                '--team-id', TEAM_ID,
                '--archive-path', str(archive),
                '--export-path', str(export_dir),
                '--app-profile', str(profiles['app']),
                '--necore-profile', str(profiles['necore']),
                '--widget-profile', str(profiles['widget']),
                '--upload-testflight',
                '--asc-api-key-id', 'TESTKEY123',
                '--asc-api-issuer-id', '00000000-0000-0000-0000-000000000000',
                '--asc-api-key-path', str(asc_key),
                *hashes,
            ], runner=runner)
            self.assertEqual(rc, 0)
            self.assertTrue(any(cmd[:2] == ['xcodebuild', '-exportArchive'] for cmd in executed))
            altool_cmds = [cmd for cmd in executed if cmd[:3] == ['xcrun', 'altool', '--upload-app']]
            self.assertEqual(len(altool_cmds), 1)
            self.assertIn('--api-key', altool_cmds[0])
            self.assertIn('--api-issuer', altool_cmds[0])
            self.assertNotIn('--p8-file-path', altool_cmds[0])


if __name__ == '__main__':
    unittest.main()
