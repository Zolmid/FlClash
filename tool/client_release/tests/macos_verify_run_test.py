import base64
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import assemble_release as release
import macos_verify_run as verify
from assemble_release_test import FakeGitHub, SHA, RUN_ID, RUN_NUMBER, TAG, standard


def dispatch(**changes):
    values = {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REPOSITORY': release.REPOSITORY,
              'GITHUB_REPOSITORY_ID': release.REPOSITORY_ID, 'GITHUB_REF': verify.BRANCH,
              'GITHUB_WORKFLOW_REF': f'{release.REPOSITORY}/{verify.WORKFLOW}@{verify.BRANCH}',
              'MACOS_NOTARIZATION_VERIFY_ENABLED': 'true'}
    values.update(changes)
    return values


class SourceGitHub(FakeGitHub):
    def __init__(self):
        super().__init__()
        example = standard()
        self.blobs, self.records = example.blobs, example.records
        repo = {'id': int(release.REPOSITORY_ID), 'full_name': release.REPOSITORY}
        self.run = {'id': RUN_ID, 'repository': repo.copy(), 'head_repository': repo.copy(),
                    'event': 'push', 'path': release.WORKFLOW, 'status': 'completed',
                    'conclusion': 'success', 'head_sha': SHA, 'run_number': RUN_NUMBER}
        self.files = {'pubspec.yaml': b'name: fl_clash\nversion: 1.2.3+2026110706\n',
                      'macos/Runner/Release.entitlements': b'<plist>source entitlements</plist>'}

    def get(self, path):
        if path.endswith(f'/actions/runs/{RUN_ID}'):
            return self.run
        prefix = f'repos/{release.REPOSITORY}/contents/'
        assert path.startswith(prefix)
        path, ref = path[len(prefix):].split('?ref=')
        assert ref == SHA
        content = self.files[path]
        return {'type': 'file', 'encoding': 'base64', 'content': base64.b64encode(content).decode(),
                'size': len(content), 'sha': hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()}


class VerifyRunTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='zolnit-macos-verify-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.output = self.root / 'result'
        self.github = SourceGitHub()

    def signer(self, directory, output, version, arch, *, context, entitlements):
        self.assertEqual(context.sha, SHA)
        self.assertEqual(context.run_id, RUN_ID)
        self.assertEqual(context.run_number, RUN_NUMBER)
        self.assertEqual(version, '1.2.3')
        self.assertEqual(entitlements.read_bytes(), self.github.files['macos/Runner/Release.entitlements'])
        self.assertIn(f'FlClash-macos-{arch}-release.zip', {p.name for p in directory.iterdir()})
        output.mkdir()
        (output / 'signed.dmg').write_bytes(b'verified')

    def execute(self, arch='arm64'):
        verify.verify_and_sign(self.github, str(RUN_ID), TAG, arch, self.output)

    def test_both_architectures_use_verified_context_and_artifact(self):
        for arch in ('arm64', 'x64'):
            with self.subTest(arch=arch):
                shutil.rmtree(self.output, ignore_errors=True)
                with mock.patch.dict(os.environ, {'GITHUB_SHA': 'f' * 40, 'GITHUB_RUN_ID': '999'}), \
                        mock.patch.object(verify.signing, 'prepare', side_effect=self.signer):
                    self.execute(arch)
                self.assertEqual((self.output / 'signed.dmg').read_bytes(), b'verified')

    def test_rejects_failed_foreign_and_wrong_run_before_signing(self):
        cases = [
            ('conclusion', 'failure'), ('status', 'in_progress'), ('event', 'workflow_dispatch'),
            ('path', '.github/workflows/cloud-build.yml'), ('head_sha', 'd' * 40),
            ('id', RUN_ID + 1), ('run_number', 0),
            ('repository', {'id': 1, 'full_name': release.REPOSITORY}),
            ('head_repository', {'id': int(release.REPOSITORY_ID), 'full_name': 'other/fork'}),
        ]
        for key, value in cases:
            with self.subTest(key=key):
                self.github = SourceGitHub()
                self.github.run[key] = value
                with mock.patch.object(verify.signing, 'prepare') as signer, self.assertRaises(release.ReleaseError):
                    self.execute()
                signer.assert_not_called()
                self.assertFalse(self.output.exists())

    def test_rejects_tag_or_artifact_digest_mismatch(self):
        self.github.commit = 'd' * 40
        with self.assertRaisesRegex(release.ReleaseError, 'tag and source run'):
            self.execute()
        self.github = SourceGitHub()
        record = next(r for r in self.github.records if r['name'] == f'flclash-macos-arm64-{RUN_NUMBER}')
        record['digest'] = 'sha256:' + '0' * 64
        with self.assertRaisesRegex(release.ReleaseError, 'artifact digest'):
            self.execute()
        self.assertFalse(self.output.exists())

    def test_artifact_run_sha_and_source_blob_integrity_are_required(self):
        record = next(r for r in self.github.records if r['name'] == f'flclash-macos-arm64-{RUN_NUMBER}')
        record['workflow_run']['head_sha'] = 'f' * 40
        with mock.patch.object(verify.signing, 'prepare') as signer, self.assertRaisesRegex(release.ReleaseError, 'another commit'):
            self.execute()
        signer.assert_not_called()
        self.github = SourceGitHub()
        original = self.github.get
        def wrong_blob(path):
            payload = original(path)
            if '/contents/pubspec.yaml?' in path:
                payload['sha'] = 'f' * 40
            return payload
        self.github.get = wrong_blob
        with mock.patch.object(verify.signing, 'prepare') as signer, self.assertRaisesRegex(release.ReleaseError, 'source file digest mismatch'):
            self.execute()
        signer.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_partial_signing_failure_does_not_publish_output(self):
        def failure(_directory, output, *_args, **_kwargs):
            output.mkdir()
            (output / 'partial.dmg').write_bytes(b'partial')
            raise verify.signing.SigningError('failure')
        with mock.patch.object(verify.signing, 'prepare', side_effect=failure), self.assertRaises(verify.signing.SigningError):
            self.execute()
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.iterdir()), [])

    def test_dispatch_gate_cannot_be_bypassed(self):
        for changes in ({'MACOS_NOTARIZATION_VERIFY_ENABLED': ''}, {'GITHUB_EVENT_NAME': 'push'},
                        {'GITHUB_REF': 'refs/heads/main'}, {'GITHUB_REPOSITORY_ID': '1'},
                        {'GITHUB_WORKFLOW_REF': 'other'}):
            with self.subTest(changes=changes):
                with self.assertRaises(release.ReleaseError):
                    verify.check_dispatch(dispatch(**changes))
                args = ['macos_verify_run.py', '--source-run-id', str(RUN_ID), '--source-tag', TAG,
                        '--arch', 'arm64', '--output', str(self.output)]
                with mock.patch.dict(os.environ, dispatch(**changes), clear=True), mock.patch.object(sys, 'argv', args), \
                        mock.patch.object(verify, 'verify_and_sign') as sign, mock.patch('sys.stderr', new_callable=io.StringIO):
                    self.assertEqual(verify.main(), 1)
                    sign.assert_not_called()
        verify.check_dispatch(dispatch())


if __name__ == '__main__':
    unittest.main()
