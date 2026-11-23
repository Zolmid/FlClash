import hashlib
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tool/client_release'))
from assemble_release import CORE, ReleaseError
from verify_candidate import verify
from macos_workflow_test import block

SHA = 'a' * 40


class CandidateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'pubspec.yaml').write_text('version: 1.2.3+45\n')
        self.env = {'GITHUB_REPOSITORY': 'Zolmid/FlClash', 'GITHUB_REPOSITORY_ID': '1420254999',
                    'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_RUN_ATTEMPT': '1',
                    'GITHUB_SHA': SHA, 'GITHUB_WORKFLOW_SHA': SHA, 'GITHUB_RUN_ID': '123',
                    'GITHUB_RUN_NUMBER': '5', 'GITHUB_WORKFLOW_REF': 'Zolmid/FlClash/.github/workflows/cloud-build.yml@refs/heads/main',
                    'CANDIDATE_PLATFORM': 'android', 'PROJECT_RESULT': 'success', 'IOS_RESULT': 'skipped'}
        self.fields = {'source_repository': 'Zolmid/FlClash', 'source_commit': SHA, 'event_sha': SHA,
                       'workflow_revision': SHA, 'workflow_ref': self.env['GITHUB_WORKFLOW_REF'],
                       'run_id': '123', 'run_attempt': '1', 'build_profile': 'zolnit', 'package_version': '1.2.3+45',
                       'native_ui': 'true', 'client_bundle': 'true', 'target': 'android-arm64',
                       'client_safe_preview': 'false', 'distribution_channel': 'direct', 'client_build_env': 'dev',
                       'client_defines': 'APP_ENV=dev;ZOLNIT_DISTRIBUTION=direct',
                       'distribution': 'development artifact; no production signing or notarization'}

    def run_candidate(self, mutate=None, record_mutate=None, duplicate=False):
        fields = dict(self.fields)
        if mutate:
            fields.update(mutate)
        provenance = ''.join(f'{k}={v}\n' for k, v in fields.items()) + f' {CORE} core/Clash.Meta (pinned)\n'
        files = {'source-provenance.txt': provenance.encode(), 'FlClash-android-arm64-development.apk': b'apk'}
        sums = ''.join(f'{hashlib.sha256(v).hexdigest()}  {k}\n' for k, v in files.items()).encode()
        archive = self.root / 'source.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for name, data in {**files, 'SHA256SUMS': sums}.items():
                z.writestr(name, data)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        record = {'name': 'flclash-android-arm64-5', 'id': 6, 'expired': False, 'digest': 'sha256:' + digest,
                  'workflow_run': {'id': 123, 'head_sha': SHA, 'repository_id': 1420254999}}
        if record_mutate:
            record.update(record_mutate)
        class Fake:
            def artifacts(self, _):
                return [record, record] if duplicate else [record]
            def download(self, _, destination):
                destination.write_bytes(archive.read_bytes())
        work = self.root / 'work'
        work.mkdir(exist_ok=True)
        with patch('verify_candidate.subprocess.check_output', side_effect=[SHA + '\n', CORE + '\n']):
            verify(self.env, self.root, Fake(), work, lambda _: None)

    def test_valid_candidate(self):
        self.run_candidate()

    def test_tampered_provenance(self):
        for key, value in [('source_commit', 'b' * 40), ('run_attempt', '2'), ('package_version', '1.2.3+46'),
                           ('client_build_env', 'stable'), ('workflow_revision', 'b' * 40)]:
            with self.subTest(key=key), tempfile.TemporaryDirectory() as tmp:
                self.root = Path(tmp)
                (self.root / 'pubspec.yaml').write_text('version: 1.2.3+45\n')
                with self.assertRaises(ReleaseError):
                    self.run_candidate({key: value})

    def test_rejects_expired_duplicate_and_wrong_digest(self):
        for changes, dup in [({'expired': True}, False), ({'digest': 'sha256:' + '0' * 64}, False), ({}, True)]:
            with self.subTest(changes=changes, duplicate=dup), tempfile.TemporaryDirectory() as tmp:
                self.root = Path(tmp)
                (self.root / 'pubspec.yaml').write_text('version: 1.2.3+45\n')
                with self.assertRaises(ReleaseError):
                    self.run_candidate(record_mutate=changes, duplicate=dup)

    def test_rerun_fails_before_artifact_fetch(self):
        self.env['GITHUB_RUN_ATTEMPT'] = '2'
        with self.assertRaisesRegex(ReleaseError, 'new workflow dispatch'):
            self.run_candidate()


class ReleaseDagTest(unittest.TestCase):
    def test_real_workflow_gates(self):
        workflow = (ROOT / '.github/workflows/client-release.yml').read_text()
        builds = block(workflow, 'builds', 2)
        signing = block(workflow, 'macos-sign', 2)
        publish = block(workflow, 'publish', 2)
        self.assertIn('needs: [preflight, ci]', builds)
        self.assertIn('needs: [preflight, ci, builds]', signing)
        expr = re.search(r'^    if: (.+)$', publish, re.M).group(1)
        for ci in ('success', 'failure', 'cancelled', 'skipped'):
            for build in ('success', 'failure', 'cancelled', 'skipped'):
                for required in ('true', 'false'):
                    for sign in ('success', 'failure', 'cancelled', 'skipped'):
                        values = {'needs.preflight.result': 'success', 'needs.ci.result': ci,
                                  'needs.builds.result': build, 'needs.preflight.outputs.macos_signing_required': required,
                                  'needs.macos-sign.result': sign}
                        python = expr.replace('always()', 'True').replace('&&', ' and ').replace('||', ' or ')
                        for key, value in values.items():
                            python = python.replace(key, repr(value))
                        actual = eval(python, {'__builtins__': {}})
                        expected = ci == build == 'success' and (sign == 'success' if required == 'true' else sign == 'skipped')
                        self.assertEqual(actual, expected, (ci, build, required, sign))


if __name__ == '__main__':
    unittest.main()
