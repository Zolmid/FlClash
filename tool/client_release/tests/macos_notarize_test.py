import base64
import hashlib
import json
import os
import shutil
import shlex
from types import SimpleNamespace
import plistlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import macos_notarize as signing


class SigningTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.app = self.root / 'ZolNit.app'
        self.macos = self.app / 'Contents/MacOS'
        self.macos.mkdir(parents=True)
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'ZolNit'}))
        (self.macos / 'ZolNit').write_bytes(bytes.fromhex('cffaedfe'))
        (self.macos / 'FlClashCore').write_bytes(bytes.fromhex('cffaedfe'))
        framework = self.app / 'Contents/Frameworks/Test.framework/Versions/A'
        framework.mkdir(parents=True)
        (framework / 'Test').write_bytes(bytes.fromhex('cffaedfe'))
        (self.app / 'Contents/Frameworks/libexample.dylib').write_bytes(bytes.fromhex('cffaedfe'))
        helper = self.app / 'Contents/Library/LoginItems/LoginHelper.app/Contents/MacOS'
        helper.mkdir(parents=True)
        (helper / 'LoginHelper').write_bytes(bytes.fromhex('cffaedfe'))
        (self.app / 'Contents/Frameworks/libclash.dylib').write_bytes(bytes.fromhex('cffaedfe'))
        self.commands = []
        self.dmg = self.root / 'final.dmg'

    def runner(self, args, **kwargs):
        cmd = [str(a) for a in args]
        self.commands.append(cmd)
        if cmd[:3] == ['xcrun', 'notarytool', 'submit']:
            return json.dumps({'status': 'Accepted', 'id': f'id-{len(self.commands)}'})
        if cmd[:2] == ['hdiutil', 'create']:
            self.dmg.write_bytes(b'dmg')
        return ''

    def package(self):
        return signing.sign_package(self.app, self.dmg, self.root, 'A' * 40, self.root / 'key.p8',
                                    'ABCDEFGHIJ', 'a' * 36, self.root / 'entitlements')

    def test_nested_signatures_and_two_notarizations_in_order(self):
        with mock.patch.object(signing, 'run', side_effect=self.runner):
            ids = self.package()
        self.assertEqual(len(ids), 2)
        signs = [cmd for cmd in self.commands if cmd[:2] == ['codesign', '--force']]
        paths = [cmd[-1] for cmd in signs]
        self.assertLess(paths.index(str(self.macos / 'FlClashCore')), paths.index(str(self.app)))
        self.assertLess(paths.index(str(self.app / 'Contents/Frameworks/Test.framework/Versions/A/Test')),
                        paths.index(str(self.app / 'Contents/Frameworks/Test.framework')))
        self.assertEqual(paths[-2:], [str(self.app), str(self.dmg)])
        self.assertTrue(all('--timestamp' in cmd for cmd in signs))
        self.assertTrue(all('--options' in cmd and 'runtime' in cmd for cmd in signs[:-1]))
        sequence = [cmd[:3] for cmd in self.commands]
        submits = [i for i, cmd in enumerate(sequence) if cmd == ['xcrun', 'notarytool', 'submit']]
        staples = [i for i, cmd in enumerate(sequence) if cmd == ['xcrun', 'stapler', 'staple']]
        create = next(i for i, cmd in enumerate(self.commands) if cmd[:2] == ['hdiutil', 'create'])
        self.assertLess(submits[0], staples[0])
        self.assertLess(staples[0], create)
        self.assertLess(create, submits[1])
        self.assertLess(submits[1], staples[1])
        self.assertEqual(sum(cmd[:3] == ['xcrun', 'stapler', 'validate'] for cmd in self.commands), 2)
        self.assertEqual(sum(cmd[:2] == ['spctl', '--assess'] for cmd in self.commands), 2)

    def test_signing_changes_core_bytes_without_inventing_helper_hash_binding(self):
        core = self.macos / 'FlClashCore'
        before = hashlib.sha256(core.read_bytes()).hexdigest()
        observed = []
        def changing_codesign(args, **kwargs):
            cmd = [str(value) for value in args]
            if cmd[:2] == ['codesign', '--force']:
                target = Path(cmd[-1])
                if target == self.app:
                    observed.append(hashlib.sha256(core.read_bytes()).hexdigest())
                elif target.is_file() and target != self.dmg:
                    target.write_bytes(target.read_bytes() + b'signed')
            return self.runner(args, **kwargs)
        with mock.patch.object(signing, 'run', side_effect=changing_codesign):
            self.package()
        after = hashlib.sha256(core.read_bytes()).hexdigest()
        self.assertNotEqual(before, after)
        self.assertEqual(observed, [after])
        self.assertFalse((self.macos / 'manifest.json').exists())
        signed = [cmd[-1] for cmd in self.commands if cmd[:2] == ['codesign', '--force']]
        helper = self.app / 'Contents/Library/LoginItems/LoginHelper.app'
        self.assertIn(str(self.app / 'Contents/Frameworks/libclash.dylib'), signed)
        self.assertLess(signed.index(str(helper / 'Contents/MacOS/LoginHelper')), signed.index(str(helper)))
        self.assertLess(signed.index(str(helper)), signed.index(str(self.app)))

    def test_unexpected_core_hash_binding_or_privileged_helper_is_rejected(self):
        manifest = self.macos / 'manifest.json'
        manifest.write_text(json.dumps({'coreSha256': hashlib.sha256((self.macos / 'FlClashCore').read_bytes()).hexdigest()}))
        with mock.patch.object(signing, 'run', side_effect=self.runner), self.assertRaisesRegex(signing.SigningError, 'Core manifest'):
            self.package()
        self.assertEqual(self.commands, [])
        manifest.unlink()
        (self.macos / 'ZolNitHelperService').write_bytes(bytes.fromhex('cffaedfe'))
        with mock.patch.object(signing, 'run', side_effect=self.runner), self.assertRaisesRegex(signing.SigningError, 'privileged Helper'):
            self.package()
        self.assertEqual(self.commands, [])

    def test_only_launch_at_login_build_zips_are_removed_before_signing(self):
        resources = self.app / 'Contents/Resources/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources'
        resources.mkdir(parents=True)
        for name in ('LaunchAtLoginHelper.zip', 'LaunchAtLoginHelper-with-runtime.zip', 'unrelated.zip'):
            (resources / name).write_bytes(b'archive')
        helper = self.app / 'Contents/Library/LoginItems/LoginHelper.app/Contents/MacOS/LoginHelper'
        before = helper.read_bytes()
        with mock.patch.object(signing, 'run', side_effect=self.runner):
            self.package()
        self.assertFalse((resources / 'LaunchAtLoginHelper.zip').exists())
        self.assertFalse((resources / 'LaunchAtLoginHelper-with-runtime.zip').exists())
        self.assertTrue((resources / 'unrelated.zip').exists())
        self.assertEqual(helper.read_bytes(), before)
        self.assertIn(str(helper), [cmd[-1] for cmd in self.commands if cmd[:2] == ['codesign', '--force']])

    def test_launch_at_login_archive_symlink_is_rejected(self):
        resources = self.app / 'Contents/Resources/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources'
        resources.mkdir(parents=True)
        outside = self.root / 'outside.zip'
        outside.write_bytes(b'keep')
        (resources / 'LaunchAtLoginHelper.zip').symlink_to(outside)
        with mock.patch.object(signing, 'run', side_effect=self.runner), self.assertRaisesRegex(signing.SigningError, 'symlink'):
            self.package()
        self.assertEqual(outside.read_bytes(), b'keep')
        self.assertFalse(self.commands)

    def test_launch_at_login_resource_directory_symlink_is_rejected(self):
        outside = self.root / 'outside-resources'
        outside.mkdir()
        marker = outside / 'LaunchAtLoginHelper.zip'
        marker.write_bytes(b'keep')
        parent = self.app / 'Contents/Resources/LaunchAtLogin_LaunchAtLogin.bundle/Contents'
        parent.mkdir(parents=True)
        (parent / 'Resources').symlink_to(outside, target_is_directory=True)
        with mock.patch.object(signing, 'run', side_effect=self.runner), self.assertRaisesRegex(signing.SigningError, 'directory must not be a symlink'):
            self.package()
        self.assertEqual(marker.read_bytes(), b'keep')
        self.assertFalse(self.commands)

    def test_identity_requires_single_valid_team_developer_id(self):
        valid = '  1) ' + 'A' * 40 + ' "Developer ID Application: Example (ABCDE12345)"\n'
        self.assertEqual(signing.select_identity(valid, 'ABCDE12345'), 'A' * 40)
        for bad in ('', valid.replace('Developer ID Application', 'Apple Distribution'),
                    valid.replace('Developer ID Application', 'Mac App Distribution'),
                    valid.replace('Developer ID Application', 'Developer ID Installer'), valid * 2,
                    valid.replace('ABCDE12345', 'ZZZZZ12345'), valid.replace('"\n', '" (CSSMERR_TP_CERT_REVOKED)\n')):
            with self.subTest(bad=bad), self.assertRaises(signing.SigningError):
                signing.select_identity(bad, 'ABCDE12345')

    def test_rejection_timeout_and_invalid_tickets_stop_packaging(self):
        for failure in ('reject', 'timeout', 'app_ticket', 'dmg_ticket'):
            with self.subTest(failure=failure):
                self.commands.clear()
                self.dmg.unlink(missing_ok=True)
                stage = self.root / 'dmg-content'
                if stage.exists():
                    import shutil
                    shutil.rmtree(stage)
                count = 0
                def runner(args, **kwargs):
                    nonlocal count
                    cmd = [str(x) for x in args]
                    if cmd[:3] == ['xcrun', 'notarytool', 'submit']:
                        count += 1
                        if failure == 'timeout' and count == 1:
                            raise signing.SigningError('xcrun timed out')
                        if failure == 'reject' and count == 1:
                            return json.dumps({'status': 'Invalid', 'id': 'rejected'})
                    if cmd[:3] == ['xcrun', 'stapler', 'validate'] and (
                            (failure == 'app_ticket' and count == 1) or (failure == 'dmg_ticket' and count == 2)):
                        raise signing.SigningError('invalid ticket')
                    return self.runner(args, **kwargs)
                with mock.patch.object(signing, 'run', side_effect=runner), self.assertRaises(signing.SigningError):
                    self.package()
                if failure != 'dmg_ticket':
                    self.assertFalse(self.dmg.exists())
                self.assertFalse(any(cmd[:2] == ['spctl', '--assess'] and str(self.dmg) in cmd
                                     for cmd in self.commands))

    def test_prepare_only_emits_verified_output_and_restores_keychains(self):
        inputs = self.root / 'input'
        inputs.mkdir()
        archive = inputs / 'FlClash-macos-arm64-release.zip'
        archive.write_bytes(b'archive')
        provenance = inputs / 'source-provenance.txt'
        provenance.write_text('\n'.join([
            'source_repository=Zolmid/FlClash', 'source_commit=' + 'c' * 40,
            'target=macos-arm64', 'client_safe_preview=false', 'native_ui=true',
            'client_bundle=true', 'distribution_channel=direct', 'client_build_env=stable',
            'official_release=true', 'client_defines=APP_ENV=stable;ZOLNIT_DISTRIBUTION=direct',
            'run=https://github.com/Zolmid/FlClash/actions/runs/42',
            ' ' + signing.release.CORE + ' core/Clash.Meta (8380d0e)',
        ]) + '\n')
        (inputs / 'SHA256SUMS').write_text(''.join(
            f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in (archive, provenance)))
        env = {'MACOS_TEAM_ID': 'ABCDE12345', 'APPLE_ASC_API_KEY_ID': 'ABCDEFGHIJ',
               'APPLE_ASC_ISSUER_ID': 'a' * 36, 'MACOS_DEVELOPER_ID_P12_PASSWORD': 'private-password',
               'MACOS_DEVELOPER_ID_P12_BASE64': base64.b64encode(b'p12').decode(),
               'APPLE_ASC_P8_BASE64': base64.b64encode(b'p8').decode()}
        context = SimpleNamespace(version='1.2.3', sha='c' * 40, run_id=42,
                                  run_url='https://github.com/Zolmid/FlClash/actions/runs/42')
        for fail in (None, 'app', 'dmg'):
            output = self.root / (fail or 'success')
            commands = []
            submissions = []
            def runner(args, **kwargs):
                cmd = [str(x) for x in args]
                commands.append(cmd)
                self.assertNotIn('private-password', cmd)
                if cmd == ['security', '-i']:
                    secret_command = shlex.split(kwargs['stdin'])
                    self.assertNotIn('exit', secret_command)
                    if secret_command[0] == 'create-keychain':
                        Path(secret_command[-1]).touch(mode=0o600)
                    if secret_command[0] == 'import':
                        self.assertEqual(Path(secret_command[1]).stat().st_mode & 0o777, 0o600)
                    return ''
                if cmd[:4] == ['security', 'list-keychains', '-d', 'user'] and '-s' not in cmd:
                    return '    "/tmp/original.keychain-db"\n'
                if cmd[:2] == ['security', 'find-identity']:
                    return '  1) ' + 'A' * 40 + ' "Developer ID Application: Example (ABCDE12345)"\n'
                if cmd[:3] == ['ditto', '-x', '-k']:
                    shutil.copytree(self.app, Path(cmd[-1]) / 'ZolNit.app')
                if cmd[:3] == ['xcrun', 'notarytool', 'submit']:
                    submissions.append(cmd)
                    return json.dumps({'status': 'Accepted', 'id': 'accepted-id'})
                if cmd[:3] == ['xcrun', 'stapler', 'validate'] and (
                        (fail == 'app' and len(submissions) == 1) or (fail == 'dmg' and len(submissions) == 2)):
                    raise signing.SigningError('invalid ticket')
                if cmd[:2] == ['hdiutil', 'create']:
                    Path(cmd[-1]).write_bytes(b'final-signed-stapled')
                return ''
            with mock.patch.dict(os.environ, env), mock.patch.object(signing.release, 'Context', return_value=context), \
                    mock.patch.object(signing, 'run', side_effect=runner):
                if fail:
                    with self.assertRaises(signing.SigningError):
                        signing.prepare(inputs, output, '1.2.3', 'arm64')
                    self.assertFalse(output.exists())
                else:
                    signing.prepare(inputs, output, '1.2.3', 'arm64')
                    receipt = json.loads((output / 'signing-receipt.json').read_text())
                    dmg = output / receipt['dmg']
                    self.assertEqual(receipt['dmg_sha256'], hashlib.sha256(dmg.read_bytes()).hexdigest())
                    self.assertEqual(receipt['input_sha256'], hashlib.sha256(archive.read_bytes()).hexdigest())
            self.assertTrue(any(cmd == ['security', 'list-keychains', '-d', 'user', '-s',
                                       '/tmp/original.keychain-db'] for cmd in commands))
            self.assertTrue(any(cmd[:2] == ['security', 'delete-keychain'] for cmd in commands))

    def test_real_runner_converts_timeout_and_nonzero_exit(self):
        for result in (subprocess.TimeoutExpired('xcrun', 1), subprocess.CompletedProcess(['xcrun'], 1, '', 'bad')):
            with self.subTest(result=result), mock.patch.object(signing.subprocess, 'run',
                    side_effect=result if isinstance(result, Exception) else None,
                    return_value=None if isinstance(result, Exception) else result), self.assertRaises(signing.SigningError):
                signing.run(['xcrun'])


if __name__ == '__main__':
    unittest.main()
