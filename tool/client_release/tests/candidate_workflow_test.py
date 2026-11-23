import ast
import hashlib
import io
import itertools
import json
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tool/client_release'))
import assemble_release as release
import candidate_packages as packages
import verify_candidate as candidate

SHA = subprocess.check_output(['git', '-C', ROOT, 'rev-parse', 'HEAD'], text=True).strip()
VERSION, BUILD = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)', (ROOT / 'pubspec.yaml').read_text(), re.M).groups()
REF = 'refs/heads/codex/native-client-shared'
WORKFLOW_REF = f'Zolmid/FlClash/.github/workflows/cloud-build.yml@{REF}'


def zipped(files):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as archive:
        for name, data in files.items():
            archive.writestr(name, data)
    return stream.getvalue()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def executable(cpu):
    if packages.mobile_sdk:
        from sdk_fixtures import macho_bytes
        return macho_bytes(cpu=cpu)
    return struct.pack('<8I', 0xfeedfacf, cpu, 0, 2, 1, 24, 0, 0) + struct.pack('<6I', 0x32, 24, 2, 0, 0, 0)


def ios_contents():
    files = {}
    for directory, suffix, point, binary in [
            ('', '', None, 'Runner'), ('PlugIns/NECore.appex/', '.NECore', 'com.apple.networkextension.packet-tunnel', 'NECore'),
            ('PlugIns/Widget.appex/', '.Widget', 'com.apple.widgetkit-extension', 'Widget')]:
        prefix = 'Payload/Runner.app/' + directory
        info = dict(CFBundleIdentifier='com.zolmid.zolnit' + suffix, CFBundleExecutable=binary,
                    CFBundleShortVersionString=VERSION, CFBundleVersion=BUILD, DTPlatformName='iphoneos', DTSDKName='iphoneos27.1')
        if point:
            info['NSExtension'] = {'NSExtensionPointIdentifier': point}
        files[prefix + 'Info.plist'] = plistlib.dumps(info)
        files[prefix + binary] = executable(0x0100000c)
    return files


def products(platform, arch):
    if platform == 'ios':
        return {f'ZolNit-{VERSION}-ios-arm64-unsigned.ipa': zipped(ios_contents())}
    if platform == 'macos':
        info = dict(CFBundleIdentifier='com.zolmid.zolnit', CFBundleExecutable='ZolNit', CFBundleShortVersionString=VERSION,
                    CFBundleVersion=BUILD, DTSDKName='macosx27.0')
        app = zipped({'ZolNit.app/Contents/Info.plist': plistlib.dumps(info),
                      'ZolNit.app/Contents/MacOS/ZolNit': executable(0x0100000c if arch == 'arm64' else 0x01000007)})
        return {f'FlClash-macos-{arch}-release.zip': app, f'ZolNit-{VERSION}-macos-{arch}.dmg': b'koly' + bytes(508)}
    raise AssertionError(platform)


class Artifacts:
    def __init__(self):
        self.records, self.downloads, self.bytes = [], [], {}

    def add(self, platform='ios', arch='arm64', *, fields=None, files=None, marker=' ', toolchain=None):
        identifier = len(self.records) + 1
        provenance = dict(source_repository='Zolmid/FlClash', source_commit=SHA, event_sha=SHA, workflow_revision=SHA,
                          workflow_ref=WORKFLOW_REF, run_id='123', run_attempt='2', build_profile='zolnit',
                          package_version=f'{VERSION}+{BUILD}', native_ui='true', client_bundle='true', apple_sdk='27.1')
        if packages.mobile_sdk:
            provenance['owned_dns'] = 'strict-v1'
        if platform == 'ios':
            name = 'ios-project-arm64-unsigned-5'
            provenance.update(source_kind='project', workflow_repository='Zolmid/FlClash', workflow_commit=SHA,
                              routing_observation='false', target='iOS arm64 physical device; simulator unsupported',
                              signing='ad hoc unsigned IPA; requires provisioning for device installation')
        else:
            name = f'flclash-{platform}-{arch}-5'
            env = 'dev' if platform == 'android' else 'stable'
            provenance.update(target=f'{platform}-{arch}', client_safe_preview='false', distribution_channel='direct',
                              client_build_env=env, client_defines=f'APP_ENV={env};ZOLNIT_DISTRIBUTION=direct',
                              distribution='development artifact; no production signing or notarization',
                              run='https://github.com/Zolmid/FlClash/actions/runs/123')
        provenance.update(fields or {})
        text = '\n'.join(f'{k}={v}' for k, v in provenance.items())
        tools = 'Flutter 3.47.6 • channel stable\ngo version go1.27.1 darwin/arm64\nrustc 1.99.0\nXcode 27.1\n'
        contents = dict(files if files is not None else products(platform, arch))
        contents['source-provenance.txt'] = f'{text}\n{marker}{release.CORE} core/Clash.Meta\n{tools if toolchain is None else toolchain}'.encode()
        contents['SHA256SUMS'] = ''.join(f'{digest(data)}  {n}\n' for n, data in contents.items()).encode()
        archive = zipped(contents)
        self.bytes[identifier] = archive
        self.records.append(dict(id=identifier, name=name, expired=False, digest='sha256:' + digest(archive),
                                 size_in_bytes=len(archive), workflow_run=dict(id=123, head_sha=SHA,
                                 repository_id=1420254999, head_repository_id=1420254999)))
        return self

    def get(self, path):
        assert path == 'repos/Zolmid/FlClash/actions/runs/123/artifacts?per_page=100'
        return dict(total_count=len(self.records), artifacts=self.records)

    def download(self, path, destination):
        match = re.fullmatch(r'repos/Zolmid/FlClash/actions/artifacts/(\d+)/zip', path)
        assert match
        self.downloads.append(int(match[1]))
        destination.write_bytes(self.bytes[int(match[1])])


class CandidateTest(unittest.TestCase):
    def verify(self, source, platform='ios', **changes):
        env = dict(GITHUB_REPOSITORY='Zolmid/FlClash', GITHUB_REPOSITORY_ID='1420254999', GITHUB_REF=REF,
                   GITHUB_REF_TYPE='branch', GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_SHA=SHA,
                   GITHUB_WORKFLOW_REF=WORKFLOW_REF, GITHUB_WORKFLOW_SHA=SHA, GITHUB_RUN_ID='123',
                   GITHUB_RUN_NUMBER='5', GITHUB_RUN_ATTEMPT='2', CANDIDATE_PLATFORM=platform, SELECT_RESULT='success',
                   PROJECT_RESULT='skipped' if platform == 'ios' else 'success',
                   IOS_RESULT='success' if platform in ('all', 'ios') else 'skipped')
        lines = []
        with tempfile.TemporaryDirectory() as tmp:
            candidate.verify({**env, **changes}, ROOT, source, tmp, lines.append)
            self.assertEqual(list(Path(tmp).iterdir()), [])
        return '\n'.join(lines)

    def test_device_ipa_and_both_macos_archives_on_clean_second_attempt(self):
        self.assertIn('ios arm64', self.verify(Artifacts().add()))
        macs = Artifacts().add('macos').add('macos', 'x64')
        self.assertIn('macos x64', self.verify(macs, 'macos'))
        self.assertEqual(macs.downloads, [1, 2])
        tag = 'refs/tags/v' + VERSION
        ref = 'Zolmid/FlClash/.github/workflows/cloud-build.yml@' + tag
        self.verify(Artifacts().add(fields={'workflow_ref': ref}), GITHUB_REF_TYPE='tag', GITHUB_REF=tag, GITHUB_WORKFLOW_REF=ref)

    def test_mixed_attempt_source_profile_toolchain_and_core(self):
        with self.assertRaisesRegex(release.ReleaseError, 'run_attempt'):
            self.verify(Artifacts().add('macos').add('macos', 'x64', fields={'run_attempt': '1'}), 'macos')
        for overrides, error in [({'fields': {'event_sha': 'f' * 40}}, 'event_sha'),
                                 ({'fields': {'source_commit': '1' * 40}}, 'source_commit'),
                                 ({'fields': {'workflow_revision': '0' * 40}}, 'workflow_revision'),
                                 ({'fields': {'package_version': VERSION + '+1'}}, 'package_version'),
                                 ({'fields': {'build_profile': 'auto'}}, 'build_profile'),
                                 ({'fields': {'official_release': 'true'}}, 'official'),
                                 ({'fields': {'routing_observation': 'true'}}, 'routing_observation'),
                                 ({'marker': '-'}, 'Core'), ({'toolchain': 'Flutter 3.47.7\n'}, 'Flutter')]:
            with self.subTest(overrides=overrides), self.assertRaisesRegex(release.ReleaseError, error):
                self.verify(Artifacts().add(**overrides))

    def test_ref_cannot_vouch_for_itself(self):
        for ref in ['Zolmid/FlClash/.github/workflows/client-release.yml@' + REF,
                    WORKFLOW_REF.replace('refs/heads/codex/native-client-shared', 'refs/heads/main')]:
            data = Artifacts().add(fields={'workflow_ref': ref})
            with self.assertRaisesRegex(release.ReleaseError, 'direct Cloud build'):
                self.verify(data, GITHUB_WORKFLOW_REF=ref)
            self.assertFalse(data.downloads)

    def test_rejects_missing_duplicate_unexpected_stale_or_invalid_records_before_download(self):
        for override, error in [({'expired': True}, 'expired'), ({'name': 'flclash-macos-arm64-safe-debug-5'}, 'unexpected'),
                                ({'size_in_bytes': 2**32}, 'size'), ({'id': 'invalid'}, 'ID'),
                                ({'workflow_run': dict(id=123, head_sha='b' * 40, repository_id=1420254999,
                                                       head_repository_id=1420254999)}, 'another commit')]:
            data = Artifacts().add()
            data.records[0].update(override)
            with self.subTest(override=override), self.assertRaisesRegex(release.ReleaseError, error):
                self.verify(data)
            self.assertFalse(data.downloads)
        with self.assertRaisesRegex(release.ReleaseError, 'duplicate'):
            self.verify(Artifacts().add().add())
        with self.assertRaisesRegex(release.ReleaseError, 'missing'):
            self.verify(Artifacts())

    def test_truncated_archive_digest_changed_member_or_extra_product(self):
        data = Artifacts().add()
        data.bytes[1] = data.bytes[1][:-12]
        with self.assertRaisesRegex(release.ReleaseError, 'truncated'):
            self.verify(data)
        data.records[0]['size_in_bytes'] = len(data.bytes[1])
        with self.assertRaisesRegex(release.ReleaseError, 'digest'):
            self.verify(data)
        data.records[0]['digest'] = 'sha256:' + digest(data.bytes[1])
        with self.assertRaisesRegex(release.ReleaseError, '(zip|truncated)'):
            self.verify(data)
        data = Artifacts().add()
        with zipfile.ZipFile(io.BytesIO(data.bytes[1])) as archive:
            files = {n: archive.read(n) for n in archive.namelist()}
        files['source-provenance.txt'] += b'changed'
        data.bytes[1] = zipped(files)
        data.records[0].update(digest='sha256:' + digest(data.bytes[1]), size_in_bytes=len(data.bytes[1]))
        with self.assertRaisesRegex(release.ReleaseError, 'SHA256SUMS'):
            self.verify(data)
        with self.assertRaisesRegex(release.ReleaseError, 'unexpected product'):
            self.verify(Artifacts().add(files={**products('ios', 'arm64'), 'extra.ipa': b'x'}))
        with self.assertRaisesRegex(release.ReleaseError, 'zip'):
            self.verify(Artifacts().add('android', files={packages.DEVELOPMENT_APK: b'apk'}), 'android')

    def test_real_ipa_members_are_checked_individually(self):
        files = ios_contents()
        for name in [n for n in files if n.endswith('Info.plist')]:
            info = plistlib.loads(files[name])
            executable_name = name[:-len('Info.plist')] + info['CFBundleExecutable']
            variants = [(name, None), (name, b'x' * (256 * 1024 + 1)), (name, plistlib.dumps({**info, 'CFBundleVersion': '0'})),
                        (name, plistlib.dumps({**info, 'DTSDKName': 'iphonesimulator27.1'})),
                        (executable_name, executable(0x01000007)), (executable_name, b'\xcf\xfa\xed\xfe')]
            for member, replacement in variants:
                contents = dict(files)
                if replacement is None:
                    del contents[member]
                else:
                    contents[member] = replacement
                ipa = {f'ZolNit-{VERSION}-ios-arm64-unsigned.ipa': zipped(contents)}
                with self.subTest(member=member), self.assertRaises(release.ReleaseError):
                    self.verify(Artifacts().add(files=ipa))


def workflow_jobs(filename):
    file = ROOT / '.github/workflows' / filename
    return json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
        "puts JSON.generate(YAML.safe_load(File.read(ARGV[0])).fetch('jobs'))", str(file)]))


def gate(expression, values, cancelled=False):
    expression = expression.removeprefix('${{').removesuffix('}}').strip()
    text = expression.replace('!cancelled()', str(not cancelled)).replace('always()', 'True')
    for key, value in values.items():
        text = text.replace(key, repr(value))
    parsed = ast.parse(text.replace('&&', ' and ').replace('||', ' or '), mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare, ast.Eq, ast.NotEq, ast.Constant)
    assert all(isinstance(node, allowed) for node in ast.walk(parsed)), expression
    return eval(compile(parsed, '<workflow gate>', 'eval'), {'__builtins__': {}})


class ReleaseDagTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.release = workflow_jobs('client-release.yml')
        cls.cloud = workflow_jobs('cloud-build.yml')

    def test_reusable_call_grants_callee_permissions_even_when_verifier_skips(self):
        builds = self.release['builds']
        self.assertEqual(builds['uses'], './.github/workflows/cloud-build.yml')
        self.assertEqual(builds['permissions'], {'contents': 'read', 'actions': 'read'})
        for job in self.cloud.values():
            for scope, permission in job.get('permissions', {'contents': 'read'}).items():
                self.assertEqual(builds['permissions'][scope], permission)
        self.assertEqual(self.cloud['verify-candidate']['permissions'], builds['permissions'])

    def test_candidate_scope_preserves_the_legacy_observer_and_replaces_only_rerun_products(self):
        ios = self.cloud['ios']
        observer = ios['env']['IOS_OBSERVER_ACCEPTANCE']
        for ref, source, profile in itertools.product((REF, 'refs/heads/main'), ('project', 'patched-reference'), ('', 'auto', 'zolnit')):
            values = {'github.ref': ref, 'needs.select.outputs.ios_source': source, 'inputs.build_profile': profile}
            self.assertEqual(gate(observer, values), ref == REF and source == 'project' and profile != 'zolnit')
        steps = {step.get('name'): step for step in ios['steps']}
        for label in ('Build and validate unsigned iOS lease observer', 'Upload unsigned iOS lease observer evidence'):
            for enabled in ('true', 'false'):
                self.assertEqual(gate(steps[label]['if'], {'env.IOS_OBSERVER_ACCEPTANCE': enabled}), enabled == 'true')
        for name in ('ios', 'project'):
            upload = self.cloud[name]['steps'][-1]['with']
            for attempt, profile in itertools.product(('1', '2'), ('zolnit', 'auto', '')):
                self.assertEqual(gate(upload['overwrite'], {'github.run_attempt': attempt, 'inputs.build_profile': profile}),
                                 attempt == '2' and profile == 'zolnit')
        verifier = self.cloud['verify-candidate']
        for event, profile, source, cancelled in itertools.product(('push', 'workflow_dispatch'), ('zolnit', 'auto'),
                                                                  ('project', 'patched-reference'), (False, True)):
            values = {'github.event_name': event, 'inputs.build_profile': profile, 'inputs.ios_source': source}
            self.assertEqual(gate(verifier['if'], values, cancelled),
                             event == 'workflow_dispatch' and profile == 'zolnit' and source == 'project' and not cancelled)

    def test_publish_and_signing_gate_against_dependency_and_cancellation_results(self):
        self.assertEqual(set(self.release['builds']['needs']), {'preflight', 'ci'})
        self.assertNotIn('if', self.release['builds'])
        self.assertEqual(set(self.release['macos-sign']['needs']), {'preflight', 'ci', 'builds'})
        flag = 'needs.preflight.outputs.macos_signing_required'
        for mode in ('true', 'false', ''):
            self.assertEqual(gate(self.release['macos-sign']['if'], {flag: mode}), mode == 'true')
        pub = self.release['publish']
        self.assertEqual(set(pub['needs']), {'preflight', 'ci', 'builds', 'macos-sign'})
        states = ('success', 'failure', 'cancelled', 'skipped')
        for pre, ci, build, sign in itertools.product(states, repeat=4):
            for required, cancelled in itertools.product(('true', 'false', ''), (True, False)):
                needs = {'needs.preflight.result': pre, 'needs.ci.result': ci, 'needs.builds.result': build,
                         'needs.macos-sign.result': sign, flag: required}
                want = pre == ci == build == 'success' and (required, sign) in [('true', 'success'), ('false', 'skipped')]
                self.assertEqual(gate(pub['if'], needs, cancelled), want and not cancelled)
        steps = [step for step in pub['steps'] if 'run' in step]
        self.assertIn('assemble_release.py assemble', steps[0]['run'])
        self.assertIn('publish_release.mjs', steps[1]['run'])
        self.assertIn('github_release.py', steps[2]['run'])
        self.assertTrue(all('if' not in step and not step.get('continue-on-error') for step in steps[:3]))


if __name__ == '__main__':
    unittest.main()
