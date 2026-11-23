import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import select_checks as selector
from standard_ci_delegation_test import workflow


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.old = os.getcwd()
        os.chdir(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Test')
        self.write('lib/code.dart', 'a')
        self.base = self.commit()

    def tearDown(self):
        os.chdir(self.old)
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', self.temp.name, *args], text=True).strip()

    def write(self, path, data):
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data)

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-qm', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def selected(self, event, ref, head, **extra):
        payload = {'before': self.base, 'repository': {'private': False},
                   'pull_request': {'base': {'sha': self.base}}, **extra}
        return selector.select(event, ref, payload, head, False)

    def test_docs_branch_and_pr_and_full_events(self):
        self.write('docs/maintenance/guide.md', 'docs')
        head = self.commit()
        for event, ref in (('push', 'refs/heads/feature'), ('pull_request', 'refs/pull/1/merge')):
            profile, jobs = self.selected(event, ref, head)
            self.assertEqual(profile, 'docs')
            self.assertFalse(any(jobs.values()))
        for event, ref in (('push', 'refs/heads/main'), ('push', 'refs/tags/v1.2.3'),
                           ('merge_group', 'refs/heads/gh-readonly-queue/main/a'),
                           ('workflow_dispatch', 'refs/heads/feature'), ('workflow_call', 'refs/heads/feature')):
            self.assertEqual(self.selected(event, ref, head)[0], 'full')
        self.assertEqual(selector.select('pull_request', 'refs/pull/1/merge',
                         {'pull_request': {'base': {'sha': self.base}}}, head, True)[0], 'full')

    def test_dart_test_only_and_unsafe_paths(self):
        self.write('test/safe_test.dart', 'test')
        head = self.commit()
        profile, jobs = self.selected('push', 'refs/heads/feature', head)
        self.assertEqual(profile, 'dart')
        self.assertEqual([key for key, value in jobs.items() if value], ['dart'])
        self.write('CHANGELOG.md', 'release')
        head = self.commit()
        self.assertEqual(self.selected('push', 'refs/heads/feature', head)[0], 'full')

    def test_rename_code_to_docs_and_unusual_filename(self):
        Path('lib/code.dart').rename('README.md')
        head = self.commit()
        self.assertEqual(self.selected('pull_request', 'refs/pull/1/merge', head)[0], 'full')
        self.write('docs/maintenance/new\nname.md', 'doc')
        head = self.commit()
        self.assertEqual(self.selected('push', 'refs/heads/feature', head)[0], 'full')

    def test_incomplete_diff_falls_back(self):
        with mock.patch.object(selector.subprocess, 'run') as run:
            run.side_effect = [None, None, None, mock.Mock(stdout=b'docs/maintenance/a.md')]
            self.assertIsNone(selector.changed_paths(self.base, self.base))
            run.side_effect = [None, None, None, mock.Mock(stdout=b'x' * 2_000_001 + b'\0')]
            self.assertIsNone(selector.changed_paths(self.base, self.base))
            run.side_effect = subprocess.TimeoutExpired('git', 30)
            self.assertIsNone(selector.changed_paths(self.base, self.base))

    def test_invalid_missing_history_and_private_policy(self):
        for bad in ('', '0' * 40, 'f' * 40, '$(bad)', None):
            self.assertIsNone(selector.changed_paths(bad, self.base))
        self.write('lib/code.dart', 'changed')
        head = self.commit()
        profile, jobs = self.selected('push', 'refs/heads/private', head, repository={'private': True})
        self.assertEqual(profile, 'full')
        self.assertFalse(any(jobs.values()))
        _, jobs = self.selected('pull_request', 'refs/pull/1/merge', head, repository={'private': True})
        self.assertTrue(all(jobs.values()))


class GateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = workflow('build.yaml')['jobs']['ci-gate']['steps'][0]['run']

    def run_gate(self, needs):
        return subprocess.run(['bash', '-e', '-c', self.script], env={**os.environ, 'NEEDS_JSON': json.dumps(needs)},
                              capture_output=True, text=True).returncode

    def fixture(self, selected=True, delegated=False):
        jobs = (*selector.CHECKS, 'desktop')
        outputs = {job.replace('-', '_'): str(selected).lower() for job in jobs}
        result = {job: {'result': 'success' if selected and (job == 'desktop' or not delegated) else 'skipped'} for job in jobs}
        result.update(selection={'result': 'success', 'outputs': outputs},
                      delegation={'result': 'success', 'outputs': {'delegated': str(delegated).lower()}},
                      review={'result': 'success'})
        return result

    def test_fork_permissions_and_cache_boundaries(self):
        build = workflow('build.yaml')
        self.assertEqual(build['permissions'], {'contents': 'read'})
        self.assertEqual(build['jobs']['review']['permissions'], {'contents': 'read'})
        for name in (*selector.CHECKS, 'desktop', 'selection', 'delegation'):
            job = build['jobs'][name]
            self.assertNotIn('secrets', json.dumps(job))
            for step in job['steps']:
                if step.get('uses', '').startswith('actions/checkout@'):
                    self.assertFalse(step['with']['persist-credentials'])
        self.assertIn("github.event_name != 'pull_request'", build['env']['BRANCH_CACHE'])
        self.assertIn("github.event_name != 'merge_group'", build['env']['BRANCH_CACHE'])
        gradle = next(step for step in build['jobs']['android']['steps'] if step.get('name') == 'Setup Gradle')
        self.assertIn("github.event_name == 'pull_request'", gradle['with']['cache-disabled'])

    def test_full_docs_and_observed_reuse(self):
        for args in ((True, False), (False, False), (True, True)):
            self.assertEqual(self.run_gate(self.fixture(*args)), 0)

    def test_failure_cancel_skip_missing_and_invalid(self):
        for job in ('dart', 'desktop', 'review', 'delegation', 'selection'):
            for result in ('failure', 'cancelled', 'skipped'):
                needs = self.fixture()
                needs[job]['result'] = result
                self.assertNotEqual(self.run_gate(needs), 0, (job, result))
        needs = self.fixture()
        del needs['selection']['outputs']['dart']
        self.assertNotEqual(self.run_gate(needs), 0)
        needs = self.fixture(False)
        needs['dart']['result'] = 'success'
        self.assertNotEqual(self.run_gate(needs), 0)


if __name__ == '__main__':
    unittest.main()
