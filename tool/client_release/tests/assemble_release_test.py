import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import assemble_release as ar  # noqa: E402

SHA = 'c' * 40
RUN_ID, RUN_NUMBER = 4242, 77
TAG, VERSION, BUILD = 'v1.2.3', '1.2.3', 2026110706
PUBLIC_NOTES = '### Bug fixes\n- Payments stay pending\n'
NOTES = ar.NOTES_BEGIN + '\n' + PUBLIC_NOTES + '\n' + ar.NOTES_END + '\n\n<!-- flclash:changelog:json\n{}\n-->\n'
SAMPLES = Path(__file__).resolve().parents[5] / 'artifacts' / 'candidate-dc131580'
TOOLCHAIN = ['Flutter 3.47.6 • channel stable • https://github.com/flutter/flutter.git',
             'Tools • Dart 3.13.5 • DevTools 2.60.0', 'go version go1.27.1 linux/amd64', 'rustc 1.99.0 (b940084d7 2026-09-28)']


def environment(**overrides):
    env = {'GITHUB_REPOSITORY': ar.REPOSITORY, 'GITHUB_REPOSITORY_ID': ar.REPOSITORY_ID, 'GITHUB_EVENT_NAME': 'push',
           'GITHUB_REF_TYPE': 'tag', 'GITHUB_REF_NAME': TAG, 'GITHUB_REF': f'refs/tags/{TAG}',
           'GITHUB_WORKFLOW_REF': f'{ar.REPOSITORY}/{ar.WORKFLOW}@refs/tags/{TAG}', 'GITHUB_SHA': SHA,
           'GITHUB_RUN_ID': str(RUN_ID), 'GITHUB_RUN_NUMBER': str(RUN_NUMBER), 'GITHUB_SERVER_URL': 'https://github.com',
           'ZOLNIT_CI_RESULT': 'success', 'ZOLNIT_BUILDS_RESULT': 'success'}
    env.update(overrides)
    return {key: value for key, value in env.items() if value is not None}


def provenance(platform, arch, **changes):
    run = f'https://github.com/{ar.REPOSITORY}/actions/runs/{RUN_ID}'
    if platform == 'ios':
        fields = {'source_kind': 'project', 'source_repository': ar.REPOSITORY, 'source_commit': SHA,
                  'workflow_repository': ar.REPOSITORY, 'workflow_commit': SHA, 'native_ui': 'true',
                  'client_bundle': 'true', 'routing_observation': 'false', 'official_release': 'true', 'run': run,
                  'target': 'iOS arm64 physical device; simulator unsupported',
                  'signing': 'ad hoc unsigned IPA; requires provisioning for device installation'}
    else:
        fields = {'source_repository': ar.REPOSITORY, 'source_commit': SHA, 'target': f'{platform}-{arch}',
                  'client_safe_preview': 'false', 'native_ui': 'true', 'client_bundle': 'true',
                  'distribution_channel': 'direct', 'client_build_env': 'stable', 'official_release': 'true',
                  'client_defines': 'APP_ENV=stable;ZOLNIT_DISTRIBUTION=direct', 'run': run,
                  'distribution': 'development artifact; no production signing or notarization'}
    core = changes.pop('core_line', f' {ar.CORE} core/Clash.Meta (8380d0e)')
    extra = changes.pop('extra_lines', [])
    fields.update(changes)
    lines = [f'{key}={value}' for key, value in fields.items() if value is not None]
    return '\n'.join(lines + extra + [core] + TOOLCHAIN) + '\n'


def signing_report(cert=ar.ANDROID_CERT, signers=1):
    return '\n'.join(['Verifies', 'Verified using v1 scheme (JAR signing): false',
                      'Verified using v2 scheme (APK Signature Scheme v2): true',
                      'Verified using v3 scheme (APK Signature Scheme v3): false', f'Number of signers: {signers}',
                      'V2 Signer: certificate DN: CN=ZolNit Android Release',
                      f'V2 Signer: certificate SHA-256 digest: {cert}']) + '\n'


def ipa_bytes(provisioned=False):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as ipa:
        ipa.writestr('Payload/Runner.app/Info.plist', b'plist')
        ipa.writestr('Payload/Runner.app/Runner', b'binary')
        if provisioned:
            ipa.writestr('Payload/Runner.app/embedded.mobileprovision', b'profile')
    return buffer.getvalue()


def target_files(platform, arch, version=VERSION):
    files = {name: f'{name} bytes'.encode() for name in ar.public_names(version, platform, arch)}
    if platform == 'android':
        files['apk-signing-report.txt'] = signing_report().encode()
    if platform == 'ios':
        files[f'ZolNit-{version}-ios-arm64-unsigned.ipa'] = ipa_bytes()
    if platform in ('linux', 'windows', 'macos'):
        files[f'FlClash-{platform}-{arch}-release.zip'] = b'development archive'
    if platform == 'linux':
        files['FlClash-linux-x64-release.tar.gz'] = b'linux bundle archive'
    files['source-provenance.txt'] = provenance(platform, arch).encode()
    return files


def sums(files, dot=False):
    return ''.join(f'{hashlib.sha256(data).hexdigest()}  {"./" if dot else ""}{name}\n'
                   for name, data in sorted(files.items())).encode()


def archive(files, with_sums=True, dot=False, raw=None):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as output:
        for name, data in files.items():
            output.writestr(name, data)
        if with_sums:
            output.writestr('SHA256SUMS', sums(files, dot))
        for info, data in raw or []:
            output.writestr(info, data)
    return buffer.getvalue()


class FakeGitHub:
    def __init__(self):
        self.blobs, self.records, self.commit, self.downloads = {}, [], SHA, []

    def add(self, name, blob, **changes):
        artifact_id = 1000 + len(self.records)
        record = {'id': artifact_id, 'name': name, 'expired': False, 'digest': 'sha256:' + hashlib.sha256(blob).hexdigest(),
                  'workflow_run': {'id': RUN_ID, 'head_sha': SHA, 'repository_id': int(ar.REPOSITORY_ID),
                                   'head_repository_id': int(ar.REPOSITORY_ID)}}
        for key, value in changes.items():
            if key == 'run':
                record['workflow_run'].update(value)
            else:
                record[key] = value
        self.records.append(record)
        self.blobs[artifact_id] = blob
        return record

    def tag_commit(self, tag):
        return self.commit

    def artifacts(self, run_id):
        assert run_id == RUN_ID
        return list(self.records)

    def download(self, path, destination):
        artifact_id = int(path.split('/')[-2])
        self.downloads.append(artifact_id)
        with open(destination, 'xb') as handle:
            handle.write(self.blobs[artifact_id])


def standard(skip=(), override=None):
    github = FakeGitHub()
    override = override or {}
    for platform, arch, template in ar.TARGETS:
        name = template.format(run=RUN_NUMBER)
        if name in skip:
            continue
        files = target_files(platform, arch)
        files.update(override.get(name, {}))
        github.add(name, archive({key: value for key, value in files.items() if value is not None}))
    notes = ar.NOTES_ARTIFACT.format(run=RUN_NUMBER)
    if notes not in skip:
        github.add(notes, archive({ar.NOTES_FILE: NOTES.encode()}, with_sums=False))
    github.add(f'flclash-macos-arm64-safe-debug-{RUN_NUMBER}', archive({'ZolNit-macos-arm64-debug-safe.zip': b'x'}))
    return github


class Workspace(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='zolnit-release-test-'))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.root = self.tmp / 'repo'
        self.root.mkdir()
        (self.root / 'pubspec.yaml').write_text(f'name: fl_clash\nversion: {VERSION}+{BUILD}\n')
        (self.root / 'changelog.json').write_text(json.dumps({'schemaVersion': 2, 'versions': [
            {'version': VERSION, 'tag': TAG, 'prerelease': False, 'groups': []}]}))
        self.stage = self.tmp / 'stage'
        self.apksigner = self.tmp / 'apksigner'
        self.fake_signer(signing_report())

    def fake_signer(self, report, code=0):
        self.apksigner.write_text(f'#!/bin/sh\ncat <<\'EOF\'\n{report}EOF\nexit {code}\n')
        self.apksigner.chmod(0o755)

    def assemble(self, github, env=None, apksigner=True):
        context = ar.Context(env or environment(), self.root)
        return ar.assemble(context, github, self.stage, env or environment(), str(self.apksigner) if apksigner else None)

    def rejects(self, github, message, env=None):
        with self.assertRaises(ar.ReleaseError) as caught:
            self.assemble(github, env)
        self.assertIn(message, str(caught.exception))


class AssembleTest(Workspace):
    def signed_github(self, *, corrupt_input=False):
        github = standard()
        for arch in ('arm64', 'x64'):
            filename = ar.public_names(VERSION, 'macos', arch)[0]
            zipname = f'FlClash-macos-{arch}-release.zip'
            data = f'signed-{arch}'.encode()
            receipt = {'schema_version': 1, 'source_commit': SHA, 'run_id': RUN_ID, 'arch': arch,
                       'input_archive': zipname,
                       'input_sha256': '0' * 64 if corrupt_input else hashlib.sha256(b'development archive').hexdigest(),
                       'dmg': filename, 'dmg_sha256': hashlib.sha256(data).hexdigest(),
                       'team_id': 'ABCDE12345', 'identity_sha1': 'A' * 40,
                       'app_notary_id': 'app-id', 'dmg_notary_id': 'dmg-id',
                       'verification': 'developer-id-notarized-stapled'}
            github.add(f'macos-distribution-{arch}-{RUN_NUMBER}',
                       archive({filename: data, 'signing-receipt.json': json.dumps(receipt).encode()}))
        return github

    def test_disabled_macos_signing_preserves_existing_release(self):
        for flag in ('', 'false'):
            with self.subTest(flag=flag):
                shutil.rmtree(self.stage, ignore_errors=True)
                self.assemble(standard(), environment(MACOS_SIGNING_REQUIRED=flag,
                                                       ZOLNIT_MACOS_SIGNING_RESULT='skipped'))
                receipt = json.loads((self.stage / 'receipt.json').read_text())
                self.assertFalse(receipt['checks']['macos_notarized'])
                for arch in ('arm64', 'x64'):
                    filename = ar.public_names(VERSION, 'macos', arch)[0]
                    self.assertEqual((self.stage / 'packages' / TAG / filename).read_bytes(),
                                     f'{filename} bytes'.encode())

    def test_linux_bundle_tar_is_covered_by_source_artifact_checksums(self):
        name = f'flclash-linux-x64-{RUN_NUMBER}'
        github = standard(skip=(name,))
        files = target_files('linux', 'x64')
        recorded_sums = sums(files)
        files['FlClash-linux-x64-release.tar.gz'] = b'tampered bundle archive'
        github.add(name, archive(files, with_sums=False, raw=[('SHA256SUMS', recorded_sums)]))
        self.rejects(github, 'FlClash-linux-x64-release.tar.gz does not match SHA256SUMS')
        self.assertFalse((self.stage / 'manifest.json').exists())

    def test_invalid_macos_signing_flag_fails_closed(self):
        self.rejects(standard(), 'must be true, false, or unset',
                     environment(MACOS_SIGNING_REQUIRED='TRUE'))
        self.assertFalse((self.stage / 'manifest.json').exists())

    def test_required_macos_signing_stages_final_bytes(self):
        env = environment(MACOS_SIGNING_REQUIRED='true', ZOLNIT_MACOS_SIGNING_RESULT='success',
                          MACOS_TEAM_ID='ABCDE12345')
        self.assemble(self.signed_github(), env)
        receipt = json.loads((self.stage / 'receipt.json').read_text())
        for arch in ('arm64', 'x64'):
            filename = ar.public_names(VERSION, 'macos', arch)[0]
            self.assertEqual((self.stage / 'packages' / TAG / filename).read_bytes(), f'signed-{arch}'.encode())
            asset = next(item for item in receipt['assets'] if item['name'] == filename)
            self.assertEqual(asset['sha256'], hashlib.sha256(f'signed-{arch}'.encode()).hexdigest())
        self.assertTrue(receipt['checks']['macos_notarized'])

    def test_required_macos_signing_rejects_missing_or_wrong_evidence(self):
        for result, github, message in (
            ('skipped', standard(), 'signing job did not succeed'),
            ('failure', standard(), 'signing job did not succeed'),
            ('cancelled', standard(), 'signing job did not succeed'),
            ('success', standard(), 'missing release evidence'),
            ('success', self.signed_github(corrupt_input=True), 'signing receipt mismatch'),
        ):
            with self.subTest(message=message):
                shutil.rmtree(self.stage, ignore_errors=True)
                env = environment(MACOS_SIGNING_REQUIRED='true', ZOLNIT_MACOS_SIGNING_RESULT=result,
                                  MACOS_TEAM_ID='ABCDE12345')
                self.rejects(github, message, env)
                self.assertFalse((self.stage / 'manifest.json').exists())

    def test_formal_run_stages_only_verified_public_packages(self):
        github = standard()
        result = self.assemble(github)
        self.assertEqual(result, {'tag': TAG, 'build': BUILD, 'source_sha': SHA, 'verified_targets': 6, 'public_assets': 8})
        manifest = json.loads((self.stage / 'manifest.json').read_text())
        receipt = json.loads((self.stage / 'receipt.json').read_text())
        names = [asset['name'] for asset in manifest['releases'][0]['assets']]
        self.assertEqual(names, sorted(names))
        self.assertEqual(len(names), 8)
        self.assertFalse(any('ios' in name or 'FlClash' in name or 'safe' in name for name in names))
        self.assertEqual(manifest['releases'][0]['notes'], PUBLIC_NOTES)
        self.assertEqual((self.stage / ar.NOTES_FILE).read_text(), PUBLIC_NOTES)
        for hidden in (ar.NOTES_BEGIN, ar.NOTES_END, 'flclash:changelog:json'):
            self.assertNotIn(hidden, manifest['releases'][0]['notes'])
        notes_evidence = next(item for item in receipt['evidence'] if item['kind'] == 'release-notes')
        self.assertEqual(notes_evidence['sha256'], hashlib.sha256(NOTES.encode()).hexdigest())
        for asset in manifest['releases'][0]['assets']:
            path = self.stage / 'packages' / TAG / asset['name']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), asset['sha256'])
            self.assertEqual(asset['url'], f'https://link.zolmid.com/client/downloads/{TAG}/{asset["name"]}')
        self.assertEqual([item['name'] for item in receipt['assets']], names)
        self.assertTrue(all(item['ci_run_id'] == RUN_ID for item in receipt['assets']))
        self.assertEqual(receipt['build'], BUILD)
        self.assertEqual(receipt['core_sha'], ar.CORE)
        kinds = {item['kind'] for item in receipt['evidence']}
        self.assertEqual(kinds, {'package-build', 'ios-unsigned-compile', 'release-notes'})
        self.assertFalse((self.stage / 'artifacts').exists())
        safe = [record['id'] for record in github.records if 'safe-debug' in record['name']]
        self.assertNotIn(safe[0], github.downloads)

    def test_manifest_satisfies_the_canonical_edge_validator(self):
        node = shutil.which('node')
        if not node:
            self.skipTest('node is not installed')
        self.assemble(standard())
        contracts = (Path(ar.__file__).parent / 'contracts.mjs').as_uri()
        script = f"import {{validateManifest}} from '{contracts}'; import {{readFileSync}} from 'node:fs';" \
                 f"validateManifest(JSON.parse(readFileSync(process.argv[1], 'utf8')));"
        subprocess.run([node, '--input-type=module', '-e', script, str(self.stage / 'manifest.json')], check=True)

    def test_rerun_produces_identical_session_inputs(self):
        self.assemble(standard())
        first = [(self.stage / name).read_bytes() for name in ('manifest.json', 'receipt.json')]
        shutil.rmtree(self.stage)
        github = standard()
        github.records.reverse()
        self.assemble(github)
        self.assertEqual(first, [(self.stage / name).read_bytes() for name in ('manifest.json', 'receipt.json')])

    def test_missing_target_or_notes_is_rejected(self):
        self.rejects(standard(skip={f'flclash-windows-x64-{RUN_NUMBER}'}), 'missing release evidence')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(skip={f'ios-project-arm64-unsigned-{RUN_NUMBER}'}), 'missing release evidence')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(skip={ar.NOTES_ARTIFACT.format(run=RUN_NUMBER)}), 'missing release evidence')

    def test_missing_public_package_is_rejected(self):
        name = f'flclash-linux-x64-{RUN_NUMBER}'
        self.rejects(standard(override={name: {f'ZolNit-{VERSION}-linux-x64.deb': None}}), 'lacks ZolNit-1.2.3-linux-x64.deb')

    def test_duplicate_artifact_is_rejected(self):
        github = standard()
        github.add(f'flclash-linux-x64-{RUN_NUMBER}', archive(target_files('linux', 'x64')))
        self.rejects(github, 'more than one flclash-linux-x64')

    def test_artifact_must_belong_to_this_run_and_commit(self):
        for change, message in (({'id': RUN_ID + 1}, 'does not belong to run'),
                                ({'head_sha': 'd' * 40}, 'another commit'),
                                ({'head_repository_id': 1}, 'from a fork')):
            github = standard()
            github.records[0]['workflow_run'].update(change)
            shutil.rmtree(self.stage, True)
            self.rejects(github, message)
        github = standard()
        github.records[0]['expired'] = True
        shutil.rmtree(self.stage, True)
        self.rejects(github, 'expired')

    def test_outer_digest_mismatch_is_rejected(self):
        github = standard()
        github.records[2]['digest'] = 'sha256:' + '0' * 64
        self.rejects(github, 'GitHub artifact digest')
        github = standard()
        github.records[2]['digest'] = None
        shutil.rmtree(self.stage, True)
        self.rejects(github, 'no artifact digest')

    def test_inner_checksums_must_cover_every_file(self):
        files = target_files('macos', 'x64')
        tampered = archive(files, with_sums=False, raw=[('SHA256SUMS', sums(files)),
                                                        ('injected.bin', b'not listed')])
        github = standard(skip={f'flclash-macos-x64-{RUN_NUMBER}'})
        github.add(f'flclash-macos-x64-{RUN_NUMBER}', tampered)
        self.rejects(github, 'does not cover the artifact exactly')

        listed = sums(files)
        files[f'ZolNit-{VERSION}-macos-x64.dmg'] = b'swapped dmg'
        github = standard(skip={f'flclash-macos-x64-{RUN_NUMBER}'})
        github.add(f'flclash-macos-x64-{RUN_NUMBER}', archive(files, with_sums=False, raw=[('SHA256SUMS', listed)]))
        shutil.rmtree(self.stage, True)
        self.rejects(github, 'does not match SHA256SUMS')

    def test_provenance_mismatches_are_rejected(self):
        name = f'flclash-windows-x64-{RUN_NUMBER}'
        cases = [
            (provenance('windows', 'x64', source_commit='d' * 40), 'source_commit'),
            (provenance('windows', 'x64', official_release=None), 'official_release'),
            (provenance('windows', 'x64', client_safe_preview='true'), 'client_safe_preview'),
            (provenance('windows', 'x64', distribution_channel=''), 'distribution_channel'),
            (provenance('windows', 'x64', native_ui='false'), 'native_ui'),
            (provenance('windows', 'x64', client_build_env='dev'), 'client_build_env'),
            (provenance('windows', 'x64', target='windows-arm64'), 'target'),
            (provenance('windows', 'x64', run='https://github.com/Zolmid/FlClash/actions/runs/1'), 'run'),
            (provenance('windows', 'x64', core_line=' ' + 'e' * 40 + ' core/Clash.Meta (e)'), 'not built from core'),
            (provenance('windows', 'x64', core_line='+' + ar.CORE + ' core/Clash.Meta (8380d0e)'), 'not built from core'),
            (provenance('windows', 'x64', extra_lines=['source_commit=' + SHA]), 'repeats source_commit'),
            (provenance('windows', 'x64', extra_lines=['+' + 'f' * 40 + ' plugins/x (f)']), 'modified submodule'),
        ]
        for text, message in cases:
            with self.subTest(message=message):
                shutil.rmtree(self.stage, True)
                self.rejects(standard(override={name: {'source-provenance.txt': text.encode()}}), message)

    def test_ios_evidence_is_kept_but_observer_builds_are_rejected(self):
        name = f'ios-project-arm64-unsigned-{RUN_NUMBER}'
        observer = provenance('ios', 'arm64', routing_observation='true')
        self.rejects(standard(override={name: {'source-provenance.txt': observer.encode()}}), 'routing_observation')
        debug = provenance('ios', 'arm64', extra_lines=['app_bundle_id=com.zolmid.zolnit.debug'])
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {'source-provenance.txt': debug.encode()}}), 'app_bundle_id')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {'acceptance-pair.json': b'{}'}}), 'routing observer')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {f'ZolNit-{VERSION}-ios-arm64-unsigned.ipa': ipa_bytes(True)}}),
                     'provisioning')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {'source-provenance.txt': provenance('ios', 'arm64', workflow_commit='d' * 40).encode()}}),
                     'workflow_commit')

    def test_android_must_carry_the_production_certificate(self):
        name = f'flclash-android-arm64-{RUN_NUMBER}'
        self.rejects(standard(override={name: {'apk-signing-report.txt': signing_report('0' * 64).encode()}}),
                     'production certificate')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {'apk-signing-report.txt': signing_report(signers=2).encode()}}),
                     'exactly one signer')
        shutil.rmtree(self.stage, True)
        self.rejects(standard(override={name: {'apk-signing-report.txt': None}}), 'no signing report')
        shutil.rmtree(self.stage, True)
        self.fake_signer(signing_report('1' * 64))
        self.rejects(standard(), 'production certificate')
        shutil.rmtree(self.stage, True)
        self.fake_signer('DOES NOT VERIFY\n', code=1)
        self.rejects(standard(), 'apksigner rejected')

    def test_notes_must_come_from_the_changelog_renderer(self):
        notes = ar.NOTES_ARTIFACT.format(run=RUN_NUMBER)
        full_visible = (
            '### Features\n'
            '- Signed subscription protection, gift-card redemption, and more reliable updates.\n'
            '- Keep the experimental iOS build available for development; public iOS installation is not included.\n\n'
            '### Bug Fixes\n'
            '- **release** Keep release notes and download details in sync when a release is retried.\n'
            '- Use ZolNit icons and start directly in the app.\n'
        )
        full_raw = (
            f'{ar.NOTES_BEGIN}\n{full_visible}\n{ar.NOTES_END}\n\n'
            '<!-- flclash:changelog:json\n'
            '{"schemaVersion":2,"versions":[{"version":"1.1.0","tag":"v1.1.0","date":"2026-11-08","prerelease":false,'
            '"groups":[{"type":"feat","entries":[{"id":"ac448d2","text":"Signed subscription protection"}]},'
            '{"type":"fix","entries":[{"id":"dc5a0c8","scope":"release","text":"Handle --\\u003e safely"}]}]}]}\n'
            '-->\n'
        ).encode()
        self.assertEqual(ar.public_notes(full_raw), full_visible)
        commented = (
            f'{ar.NOTES_BEGIN}\n<!-- hidden banner -->\n### Features\n'
            f'- **release** Keep <!-- internal note --> visible copy\n{ar.NOTES_END}\n'
        ).encode()
        self.assertEqual(ar.public_notes(commented), '### Features\n- **release** Keep  visible copy\n')
        for files, message in (({ar.NOTES_FILE: b'# hand written'}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_END}\n- item\n{ar.NOTES_BEGIN}\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item\n{ar.NOTES_BEGIN}\n{ar.NOTES_END}\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item\n{ar.NOTES_END}\n{ar.NOTES_END}\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item {ar.NOTES_END}\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item\n{ar.NOTES_END}trailing\n'.encode()}, 'not rendered'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n   \n<!-- only comment -->\n{ar.NOTES_END}\n'.encode()}, 'no visible public content'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item <!-- unclosed\n{ar.NOTES_END}\n'.encode()}, 'unclosed comment'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item --> <!-- unclosed\n{ar.NOTES_END}\n'.encode()}, 'unclosed comment'),
                               ({ar.NOTES_FILE: f'{ar.NOTES_BEGIN}\n- item <!-- outer <!-- inner --> -->\n{ar.NOTES_END}\n'.encode()}, 'unclosed comment'),
                               ({ar.NOTES_FILE: NOTES.encode(), 'extra.md': b'x'}, 'must contain only'),
                               ({ar.NOTES_FILE: (NOTES + 'x' * 40000).encode()}, 'exceed 32 KiB')):
            github = standard(skip={notes})
            github.add(notes, archive(files, with_sums=False))
            shutil.rmtree(self.stage, True)
            self.rejects(github, message)

    def test_gates_refuse_unfinished_or_untrusted_runs(self):
        self.rejects(standard(), 'must succeed', environment(ZOLNIT_BUILDS_RESULT='skipped'))
        self.rejects(standard(), 'must succeed', environment(ZOLNIT_CI_RESULT=None))
        github = standard()
        github.commit = 'd' * 40
        self.rejects(github, 'no longer points')
        for env, message in ((environment(GITHUB_REF_TYPE='branch'), 'formal semver tag'),
                             (environment(GITHUB_REF_NAME='v1.2.3-rc.1', GITHUB_REF='refs/tags/v1.2.3-rc.1'), 'formal semver tag'),
                             (environment(GITHUB_EVENT_NAME='workflow_dispatch'), 'tag push'),
                             (environment(GITHUB_REPOSITORY='someone/FlClash'), 'repository'),
                             (environment(GITHUB_WORKFLOW_REF=f'{ar.REPOSITORY}/.github/workflows/build.yaml@refs/tags/{TAG}'),
                              'client-release.yml')):
            with self.subTest(message=message), self.assertRaises(ar.ReleaseError) as caught:
                ar.Context(env, self.root)
            self.assertIn(message, str(caught.exception))
        (self.root / 'pubspec.yaml').write_text('version: 1.2.4+5\n')
        with self.assertRaises(ar.ReleaseError):
            ar.Context(environment(), self.root)


class ExtractTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='zolnit-extract-test-'))
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def extract(self, entries, limit=ar.MAX_ARTIFACT_BYTES):
        path = self.tmp / 'a.zip'
        with zipfile.ZipFile(path, 'w') as output, warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            for info, data in entries:
                output.writestr(info, data)
        target = self.tmp / 'out'
        shutil.rmtree(target, True)
        return ar.extract(path, target, limit)

    def test_unsafe_members_are_refused(self):
        link = zipfile.ZipInfo('ZolNit.apk')
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        cases = [([('../escape', b'x')], 'unsafe'), ([('dir/file', b'x')], 'unsafe'), ([('/abs', b'x')], 'unsafe'),
                 ([('.hidden', b'x')], 'unsafe'), ([('a\\b', b'x')], 'unsafe'), ([(link, b'/etc/passwd')], 'non-regular'),
                 ([('dup', b'1'), ('dup', b'2')], 'duplicate'), ([('big', b'x' * 64)], 'size limit')]
        for entries, message in cases:
            with self.subTest(message=message, entries=[str(e[0]) for e in entries]):
                with self.assertRaises(ar.ReleaseError) as caught:
                    self.extract(entries, limit=32)
                self.assertIn(message, str(caught.exception))
                self.assertEqual(list((self.tmp / 'out').iterdir()) if (self.tmp / 'out').exists() else [], [])

    def test_plain_flat_archive_extracts(self):
        self.assertEqual(self.extract([('SHA256SUMS', b''), ('a.txt', b'1')]), {'SHA256SUMS', 'a.txt'})


class PreflightTest(Workspace):
    def test_preflight_records_version_and_build(self):
        output = self.tmp / 'output'
        code = ar.main(['--root', str(self.root), 'preflight'], environment(GITHUB_OUTPUT=str(output)), FakeGitHub())
        self.assertEqual(code, 0)
        self.assertEqual(output.read_text(), f'version={VERSION}\nbuild={BUILD}\n')

    def test_preflight_requires_a_committed_changelog_entry_and_unmoved_tag(self):
        (self.root / 'changelog.json').write_text(json.dumps({'versions': [{'tag': 'v1.2.2', 'prerelease': False}]}))
        self.assertEqual(ar.main(['--root', str(self.root), 'preflight'], environment(), FakeGitHub()), 1)
        (self.root / 'changelog.json').write_text(json.dumps({'versions': [{'tag': TAG, 'prerelease': False}]}))
        github = FakeGitHub()
        github.commit = 'd' * 40
        self.assertEqual(ar.main(['--root', str(self.root), 'preflight'], environment(), github), 1)


@unittest.skipUnless(SAMPLES.is_dir(), 'verified candidate-dc131580 samples are not available')
class RealSampleTest(unittest.TestCase):
    """Read-only check that the parser handles the actual Cloud build output."""

    def sample(self, folder):
        directory = SAMPLES / folder
        return directory, json.loads((directory / 'artifact-receipt.json').read_text())

    def test_actual_archives_and_provenance_parse_as_recorded(self):
        for folder in ('android-arm64-signed', 'ios-arm64', 'windows-x64', 'macos-x64-release', 'macos-arm64-release', 'linux-x64'):
            with self.subTest(folder=folder):
                directory, receipt = self.sample(folder)
                archive_path = directory / f'github-artifact-{receipt["artifact_id"]}.zip'
                self.assertEqual(ar.sha256_file(archive_path), receipt['outer_sha256'])
                with tempfile.TemporaryDirectory() as work:
                    target = Path(work) / 'x'
                    names = ar.extract(archive_path, target)
                    listed = ar.verify_sums(target, names)
                    self.assertEqual(sorted(listed), sorted(receipt['verified_inner_files']))
                fields, modules = ar.parse_provenance((directory / 'source-provenance.txt').read_text())
                self.assertEqual(fields['source_commit'], receipt['source_sha'])
                self.assertIn((' ', ar.CORE, 'core/Clash.Meta'), modules)

    def test_development_candidates_are_not_formal(self):
        class Sample:
            sha = 'dc131580e9f517ca359567d1e44c759feeec56c9'
        for folder, platform, arch, message in (('android-arm64-signed', 'android', 'arm64', 'official_release'),
                                                ('linux-x64', 'linux', 'x64', 'official_release'),
                                                ('ios-arm64', 'ios', 'arm64', 'app_bundle_id')):
            directory, receipt = self.sample(folder)
            Sample.run_url = f'https://github.com/{ar.REPOSITORY}/actions/runs/{receipt["run_id"]}'
            with self.subTest(folder=folder), self.assertRaises(ar.ReleaseError) as caught:
                ar.check_provenance((directory / 'source-provenance.txt').read_text(), Sample, platform, arch)
            self.assertIn(message, str(caught.exception))
        ar.check_android_signing((SAMPLES / 'android-arm64-signed' / 'apk-signing-report.txt').read_text())


if __name__ == '__main__':
    unittest.main()
