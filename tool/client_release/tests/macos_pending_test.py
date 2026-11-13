import base64
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import assemble_release as release
import macos_notarize as signing
import macos_pending as pending
from assemble_release_test import FakeGitHub, archive

ID1 = '11111111-1111-1111-1111-111111111111'
ID2 = '22222222-2222-2222-2222-222222222222'
BINDING = {'source_repository': release.REPOSITORY, 'core_sha': release.CORE, 'source_commit': 'c' * 40, 'source_run_id': 42,
           'version': '1.2.3', 'arch': 'arm64', 'input_archive': 'FlClash-macos-arm64-release.zip',
           'input_sha256': 'd' * 64, 'team_id': 'ABCDE12345', 'identity_sha1': 'A' * 40, 'source_artifact_id': 100,
           'source_artifact_sha256': 'e' * 64, 'source_provenance_sha256': 'f' * 64}


class PendingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='zolnit-pending-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.payload = self.root / 'payload.zip'
        self.payload.write_bytes(b'signed bytes')
        self.checkpoint = pending.Checkpoint(self.root / 'checkpoint', BINDING)

    def saved(self):
        self.checkpoint.reserve(self.payload, 'app')
        self.checkpoint.submitted(ID1)
        return self.checkpoint

    def test_submission_id_and_exact_bytes_are_saved_before_wait(self):
        def runner(args, **_):
            args = [str(a) for a in args]
            saved = json.loads((self.checkpoint.directory / pending.RECEIPT).read_text())
            self.assertEqual(saved['payloads']['notary-app.zip']['sha256'], hashlib.sha256(b'signed bytes').hexdigest())
            if args[2] == 'submit':
                self.assertIn('--no-wait', args)
                self.assertNotIn('--wait', args)
                self.assertIsNone(saved['submission_id'])
                return json.dumps({'id': ID1, 'status': 'In Progress'})
            self.assertEqual(saved['submission_id'], ID1)
            return json.dumps({'id': ID1, 'status': 'In Progress'})
        with mock.patch.object(signing, 'run', side_effect=runner), self.assertRaisesRegex(signing.SigningError, 'pending'):
            signing.submit(self.payload, 'key', 'id', 'issuer', self.checkpoint, 'app')
        self.assertEqual({p.name for p in self.checkpoint.directory.iterdir()}, {pending.RECEIPT, 'notary-app.zip'})
        loaded = pending.Checkpoint(self.root / 'resumed', BINDING, self.checkpoint.directory)
        self.assertEqual(loaded.data['submission_id'], ID1)

    def test_unknown_submit_outcome_is_retained_and_not_resubmitted(self):
        with mock.patch.object(signing, 'run', side_effect=signing.SigningError('xcrun notarytool submit timed out')), self.assertRaises(signing.SigningError):
            signing.submit(self.payload, 'key', 'id', 'issuer', self.checkpoint, 'app')
        with self.assertRaisesRegex(pending.PendingError, 'outcome unknown'):
            pending.Checkpoint(self.root / 'retry', BINDING, self.checkpoint.directory)
        self.assertEqual(self.checkpoint.data['state'], 'submitting')

    def test_tampered_bytes_foreign_binding_and_extra_files_are_rejected(self):
        self.saved()
        for key in ('source_commit', 'arch', 'team_id', 'input_sha256'):
            with self.subTest(key=key), self.assertRaisesRegex(pending.PendingError, 'mismatch'):
                pending.Checkpoint(self.root / 'retry', {**BINDING, key: 'wrong'}, self.checkpoint.directory)
        data = self.checkpoint.directory / 'notary-app.zip'
        data.write_bytes(b'tampered')
        with self.assertRaisesRegex(pending.PendingError, 'checksum mismatch'):
            pending.Checkpoint(self.root / 'retry', BINDING, self.checkpoint.directory)
        data.write_bytes(b'signed bytes')
        (self.checkpoint.directory / 'AuthKey.p8').write_text('synthetic forbidden material')
        with self.assertRaisesRegex(pending.PendingError, 'unexpected checkpoint files'):
            pending.Checkpoint(self.root / 'retry', BINDING, self.checkpoint.directory)

    def test_rejected_submission_cannot_fall_back_to_submit(self):
        self.saved()
        self.checkpoint.status('Invalid')
        with self.assertRaisesRegex(pending.PendingError, 'rejected'):
            pending.Checkpoint(self.root / 'retry', BINDING, self.checkpoint.directory)

    def test_three_mac_stages_continue_without_duplicate_app_or_dmg_upload(self):
        work = self.root / 'work'
        app = work / 'ZolNit.app'
        (app / 'Contents/MacOS').mkdir(parents=True)
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.zolmid.zolnit', 'CFBundleExecutable': 'ZolNit', 'LSMinimumSystemVersion': '13.0'}))
        for name in ('ZolNit', 'FlClashCore'):
            (app / 'Contents/MacOS' / name).write_bytes(bytes.fromhex('cffaedfe'))
        commands, submitted = [], []
        def runner(args, **_):
            cmd = [str(a) for a in args]
            commands.append(cmd)
            if cmd[:3] == ['ditto', '-c', '-k']:
                Path(cmd[-1]).write_bytes(b'signed app')
            if cmd[:3] == ['xcrun', 'notarytool', 'submit']:
                submitted.append(cmd)
                return json.dumps({'id': ID1 if len(submitted) == 1 else ID2, 'status': 'In Progress'})
            if cmd[:3] == ['xcrun', 'notarytool', 'info']:
                return json.dumps({'id': cmd[3], 'status': 'Accepted'})
            if cmd[:2] == ['hdiutil', 'create']:
                Path(cmd[-1]).write_bytes(b'signed dmg')
            if cmd[:3] == ['xcrun', 'stapler', 'staple'] and cmd[-1].endswith('.dmg'):
                with Path(cmd[-1]).open('ab') as target:
                    target.write(b' stapled')
            return ''
        args = (app, work / 'final.dmg', work, 'A' * 40, 'key', 'kid', 'issuer', self.root / 'entitlements')
        with mock.patch.object(signing, 'run', side_effect=runner):
            self.assertIsNone(signing.sign_package(*args, checkpoint=self.checkpoint, mode='app'))
            self.assertEqual(len(submitted), 1)
            cp2 = pending.Checkpoint(self.root / 'cp2', BINDING, self.checkpoint.directory)
            self.assertIsNone(signing.sign_package(*args, checkpoint=cp2, mode='dmg'))
            self.assertEqual(len(submitted), 2)
            cp3 = pending.Checkpoint(self.root / 'cp3', BINDING, cp2.directory)
            result = signing.sign_package(*args, checkpoint=cp3, mode='final')
        self.assertEqual(result, (ID1, ID2))
        self.assertEqual(len(submitted), 2)
        self.assertFalse(any(cmd[:3] == ['xcrun', 'notarytool', 'wait'] for cmd in commands))
        self.assertEqual((work / 'final.dmg').read_bytes(), b'signed dmg stapled')
        self.assertEqual((cp3.directory / 'notary-dmg.dmg').read_bytes(), b'signed dmg')

    def test_resume_requires_trusted_team_timestamp_and_hardened_runtime(self):
        for detail in ('TeamIdentifier=WRONG12345\nTimestamp=t\nflags=runtime\n',
                       'TeamIdentifier=ABCDE12345\nflags=runtime\n',
                       'TeamIdentifier=ABCDE12345\nTimestamp=t\nflags=0\n'):
            with self.subTest(detail=detail), mock.patch.object(signing, 'run', return_value=detail), self.assertRaisesRegex(signing.SigningError, 'signature or team'):
                signing.verify_signature(self.payload, 'ABCDE12345', runtime=True)
        with mock.patch.object(signing, 'run', return_value='TeamIdentifier=ABCDE12345\nTimestamp=t\nflags=0x10000(runtime)\n') as run:
            signing.verify_signature(self.payload, 'ABCDE12345', runtime=True)
        requirement = run.call_args_list[0].args[0]
        self.assertIn('-R', requirement)
        self.assertIn('certificate leaf[field.1.2.840.113635.100.6.1.13] exists', requirement[requirement.index('-R') + 1])

    def test_prepare_resumes_with_expired_original_zip_and_no_app_resubmission(self):
        with zipfile.ZipFile(self.payload, 'w') as z:
            z.writestr('ZolNit.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleIdentifier': 'com.zolmid.zolnit', 'CFBundleExecutable': 'ZolNit', 'LSMinimumSystemVersion': '13.0'}))
            for name in ('ZolNit', 'FlClashCore'):
                z.writestr('ZolNit.app/Contents/MacOS/' + name, bytes.fromhex('cffaedfe'))
        self.saved()
        env = {'MACOS_TEAM_ID': 'ABCDE12345', 'APPLE_ASC_API_KEY_ID': 'ABCDEFGHIJ',
               'APPLE_ASC_ISSUER_ID': ID1, 'MACOS_DEVELOPER_ID_P12_PASSWORD': 'synthetic-password',
               'MACOS_DEVELOPER_ID_P12_BASE64': base64.b64encode(b'synthetic-p12').decode(),
               'APPLE_ASC_P8_BASE64': base64.b64encode(b'synthetic-p8').decode()}
        context = SimpleNamespace(sha='c' * 40, run_id=42, version='1.2.3')
        evidence = pending.source_evidence(self.checkpoint.directory, context, 'arm64')
        commands = []
        def runner(args, **kwargs):
            cmd = [str(x) for x in args]
            commands.append(cmd)
            if cmd == ['security', 'list-keychains', '-d', 'user']:
                return '"/tmp/original.keychain-db"'
            if cmd[:2] == ['security', 'find-identity']:
                return '  1) ' + 'A' * 40 + ' "Developer ID Application: Test (ABCDE12345)"'
            if cmd[:3] == ['ditto', '-x', '-k']:
                with zipfile.ZipFile(cmd[3]) as z:
                    z.extractall(cmd[4])
            if cmd[:3] == ['codesign', '-d', '--verbose=4']:
                return 'TeamIdentifier=ABCDE12345\nTimestamp=t\nflags=0x10000(runtime)\n'
            if cmd[:3] == ['xcrun', 'notarytool', 'info']:
                return json.dumps({'id': ID1, 'status': 'Accepted'})
            if cmd[:3] == ['xcrun', 'notarytool', 'submit']:
                self.assertEqual(Path(cmd[3]).name, 'notary-dmg.dmg')
                return json.dumps({'id': ID2, 'status': 'In Progress'})
            if cmd[:2] == ['hdiutil', 'create']:
                Path(cmd[-1]).write_bytes(b'signed dmg')
            return ''
        output, saved = self.root / 'output', self.root / 'new-checkpoint'
        with mock.patch.dict(os.environ, env), mock.patch.object(signing, 'run', side_effect=runner):
            signing.prepare(None, output, '1.2.3', 'arm64', context=context, resume=self.checkpoint.directory,
                            pending_dir=saved, source_evidence=evidence, mode='dmg')
        self.assertFalse(output.exists())
        self.assertEqual(sum(cmd[:3] == ['xcrun', 'notarytool', 'submit'] for cmd in commands), 1)
        self.assertEqual(json.loads((saved / pending.RECEIPT).read_text())['submission_id'], ID2)
        self.assertEqual({p.name for p in saved.iterdir()}, {pending.RECEIPT, *pending.PAYLOADS.values()})
        self.assertTrue(any(cmd[:2] == ['codesign', '--verify'] and '-R' in cmd for cmd in commands))

    def test_retry_chooses_latest_stage_and_refuses_missing_checkpoint(self):
        github = FakeGitHub()
        github.records = [{'name': f'macos-notary-checkpoint-arm64-100-1-{stage}', 'id': i}
                          for i, stage in enumerate(('app', 'dmg', 'final'), 1)]
        github.artifacts = lambda _run_id: github.records
        env = {'GITHUB_RUN_ID': '100', 'GITHUB_RUN_ATTEMPT': '2'}
        with mock.patch.object(pending, 'download_checkpoint', return_value='checked') as fetch:
            self.assertEqual(pending.select_checkpoint(github, 'old-explicit', None, 'arm64', self.root, env), 'checked')
            self.assertEqual(fetch.call_args.args[1], 3)
        github.records = []
        with self.assertRaisesRegex(pending.PendingError, 'no checkpoint'):
            pending.select_checkpoint(github, '', None, 'arm64', self.root, env)

    def retry_fixture(self, records=(), jobs=None):
        github = FakeGitHub()
        github.artifacts = lambda run_id: list(records)
        job = {'run_id': 100, 'run_attempt': 1, 'status': 'completed', 'conclusion': 'skipped',
               'name': 'Notarize verification · arm64 / macOS dmg · arm64', 'steps': []}
        history = [job] if jobs is None else jobs
        github.get = mock.Mock(return_value={'total_count': len(history), 'jobs': history})
        return github, {'GITHUB_RUN_ID': '100', 'GITHUB_RUN_ATTEMPT': '2'}, job

    def test_dmg_retry_prefers_saved_dmg_or_final_over_explicit_upstream_app(self):
        saved = self.root / 'saved-dmg'
        saved.mkdir()
        (saved / pending.RECEIPT).write_text(json.dumps({'stage': 'dmg', 'submission_id': ID2}))
        for stages in (('app', 'dmg'), ('app', 'dmg', 'final')):
            with self.subTest(stages=stages):
                records = [{'name': f'macos-notary-checkpoint-arm64-100-1-{stage}', 'id': i}
                           for i, stage in enumerate(stages, 1)]
                github, env, _ = self.retry_fixture(records)
                with mock.patch.object(pending, 'download_checkpoint', return_value=saved) as fetch:
                    result = pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
                self.assertEqual(result, saved)
                self.assertEqual(fetch.call_args.args[1], len(stages))
                github.get.assert_not_called()

    def test_dmg_retry_reconciles_if_previous_signing_step_ran_without_checkpoint(self):
        for conclusion in ('success', 'failure', 'cancelled'):
            with self.subTest(conclusion=conclusion):
                github, env, job = self.retry_fixture()
                job.update(conclusion=conclusion, steps=[{'name': 'Verify and perform dmg stage',
                                                        'status': 'completed', 'conclusion': conclusion}])
                with mock.patch.object(pending, 'download_checkpoint') as fetch, \
                        self.assertRaisesRegex(pending.PendingError, 'DMG stage ran without a checkpoint'):
                    pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
                fetch.assert_not_called()
                github.get.assert_called_once_with('repos/Zolmid/FlClash/actions/runs/100/attempts/1/jobs?per_page=100&page=1')

    def test_wait_app_only_retry_permits_first_dmg_submission(self):
        for skipped_job in ('job-skipped', 'step-skipped', 'not-scheduled'):
            with self.subTest(skipped_job=skipped_job):
                github, env, job = self.retry_fixture()
                if skipped_job == 'step-skipped':
                    job.update(conclusion='failure', steps=[{'name': 'Verify and perform dmg stage',
                                                            'status': 'completed', 'conclusion': 'skipped'}])
                elif skipped_job == 'not-scheduled':
                    job.update(name='Await Apple app acceptance · arm64', conclusion='failure')
                with mock.patch.object(pending, 'download_checkpoint', return_value='verified-app') as fetch:
                    result = pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
                self.assertEqual(result, 'verified-app')
                self.assertEqual(fetch.call_args.args[1], 'upstream-app')

    def test_dmg_history_is_paginated_and_unknown_history_fails_closed(self):
        github, env, job = self.retry_fixture()
        job.update(conclusion='failure', steps=[{'name': 'Verify and perform dmg stage',
                                                'status': 'completed', 'conclusion': 'failure'}])
        other = {**job, 'name': 'Notarize verification · x64 / macOS dmg · x64'}
        github.get.side_effect = [{'total_count': 2, 'jobs': [other]}, {'total_count': 2, 'jobs': [job]}]
        with mock.patch.object(pending, 'download_checkpoint') as fetch, self.assertRaisesRegex(pending.PendingError, 'DMG stage ran'):
            pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
        fetch.assert_not_called()
        self.assertTrue(github.get.call_args.args[0].endswith('page=2'))
        github.get.side_effect = None
        github.get.return_value = {'total_count': 1, 'jobs': [{**job, 'steps': []}]}
        with self.assertRaisesRegex(pending.PendingError, 'history unavailable'):
            pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
        github.get.return_value = {'total_count': 1, 'jobs': [{**job, 'name': 'Unidentified DMG job'}]}
        with self.assertRaisesRegex(pending.PendingError, 'history unavailable'):
            pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')

    def test_dmg_named_checkpoint_without_saved_submission_does_not_repeat_upload(self):
        records = [{'name': 'macos-notary-checkpoint-arm64-100-1-dmg', 'id': 9}]
        github, env, _ = self.retry_fixture(records)
        saved = self.root / 'saved'
        saved.mkdir()
        for data in ({'stage': 'app', 'submission_id': ID1}, {'stage': 'dmg', 'submission_id': None}):
            with self.subTest(data=data):
                (saved / pending.RECEIPT).write_text(json.dumps(data))
                with mock.patch.object(pending, 'download_checkpoint', return_value=saved) as fetch, \
                        self.assertRaises(pending.PendingError):
                    pending.select_checkpoint(github, 'upstream-app', None, 'arm64', self.root, env, mode='dmg')
                self.assertEqual(fetch.call_count, 1)
                self.assertEqual(fetch.call_args.args[1], 9)

    def test_final_retry_can_reuse_explicit_dmg_without_submission_history(self):
        github, env, _ = self.retry_fixture()
        with mock.patch.object(pending, 'download_checkpoint', return_value='verified-dmg') as fetch:
            self.assertEqual(pending.select_checkpoint(github, 'upstream-dmg', None, 'arm64', self.root, env, mode='final'), 'verified-dmg')
        self.assertEqual(fetch.call_args.args[1], 'upstream-dmg')
        github.get.assert_not_called()

    def test_pending_producer_and_outer_digest_are_verified(self):
        self.saved()
        github = FakeGitHub()
        record = github.add('macos-notary-checkpoint-arm64-4242-1-app', archive(
            {p.name: p.read_bytes() for p in self.checkpoint.directory.iterdir()}, with_sums=False))
        repo = {'id': int(release.REPOSITORY_ID), 'full_name': release.REPOSITORY}
        origin = {'id': 4242, 'repository': repo, 'head_repository': repo,
                  'path': pending.MANUAL_WORKFLOW, 'event': 'workflow_dispatch', 'head_branch': pending.BRANCH,
                  'head_sha': 'c' * 40, 'run_attempt': 1, 'status': 'completed'}
        github.get = lambda path: record if '/artifacts/' in path else origin
        context = SimpleNamespace(sha='c' * 40, tag='v1.2.3')
        origin['path'] = '.github/workflows/foreign.yml'
        with self.assertRaisesRegex(pending.PendingError, 'producer workflow'):
            pending.download_checkpoint(github, record['id'], context, 'arm64', self.root)
        origin['path'] = pending.MANUAL_WORKFLOW
        record['digest'] = 'sha256:' + '0' * 64
        with self.assertRaisesRegex(release.ReleaseError, 'artifact digest'):
            pending.download_checkpoint(github, record['id'], context, 'arm64', self.root)


if __name__ == '__main__':
    unittest.main()
