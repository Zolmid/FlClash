import copy
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import standard_ci_reuse as reuse  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
FIXTURE = Path(__file__).parent / 'fixtures/standard_ci_v1.1.9.json'
CHECK_IDS = ('dart', 'plugins', 'go', 'android', 'rust', 'windows-helper-test')


def workflow(name):
    code = "require 'yaml'; require 'json'; puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))"
    return json.loads(subprocess.check_output(['ruby', '-e', code, str(ROOT / '.github/workflows' / name)], text=True))


def event(tag='v1.1.9', **changes):
    ref = f'refs/tags/{tag}'
    data = {'GITHUB_EVENT_NAME': 'push', 'GITHUB_REPOSITORY': 'Zolmid/FlClash',
            'GITHUB_REPOSITORY_ID': '1420254999', 'GITHUB_REF_TYPE': 'tag',
            'GITHUB_REF': ref, 'GITHUB_REF_NAME': tag,
            'GITHUB_WORKFLOW_REF': f'Zolmid/FlClash/.github/workflows/build.yaml@{ref}',
            'GITHUB_SHA': 'bfb49ed8a41a9b531a64783f9407959085e4444e',
            'GITHUB_SERVER_URL': 'https://github.com', 'GITHUB_API_URL': 'https://api.github.com',
            'EVENT_DELETED': 'false', 'OFFICIAL_INPUT': 'null'}
    data.update(changes)
    return data


def check_enabled(expression, selected, delegated='', cancelled=False):
    facts = {'!cancelled()': not cancelled, "needs.delegation.outputs.delegated != 'true'": delegated != 'true'}
    for job in (*CHECK_IDS, 'desktop', 'apple-renewal'):
        facts[f"needs.selection.outputs.{job.replace('-', '_')} == 'true'"] = job in selected
    return all(facts[term] for term in expression.removeprefix('${{').removesuffix('}}').strip().split(' && '))


class Clock:
    def __init__(self):
        self.now = 0
        self.sleeps = []

    def __call__(self):
        return self.now

    def sleep(self, duration):
        self.sleeps.append(duration)
        self.now += duration


class DelegationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = workflow('build.yaml')
        cls.release = workflow('client-release.yml')

    def setUp(self):
        fixture = json.loads(FIXTURE.read_text())
        self.run, self.jobs = fixture['run'], fixture['jobs']
        apple = copy.deepcopy(next(job for job in self.jobs['jobs'] if job['name'] == 'Standard CI / Dart'))
        apple.update(name='Standard CI / Apple renewal', id=987654321)
        self.jobs['jobs'].append(apple)
        self.jobs['total_count'] += 1
        self.source = (self.run['id'], self.run['run_attempt'])

    def decision(self):
        return reuse.decide(self.run, self.jobs, event(), self.source)

    def job(self, name):
        return next(job for job in self.jobs['jobs'] if job['name'] == name)

    def observe(self, responses):
        calls, logs, clock = [], [], Clock()
        iterator = iter(responses)

        def get(path, timeout):
            calls.append((path, timeout))
            response = next(iterator)
            if isinstance(response, Exception):
                raise response
            return response

        result = reuse.observe(event(), get, clock, clock.sleep, logs.append)
        return result, calls, clock, logs

    def response_sequence(self, final=None):
        return [{'total_count': 1, 'workflow_runs': [self.run]}, self.run, self.jobs,
                self.run if final is None else final]

    def test_extended_record_reuses_seven_checks_independently_of_publisher(self):
        for overall in ('success', 'failure', None):
            with self.subTest(overall=overall):
                self.run.update(conclusion=overall, status='in_progress' if overall is None else 'completed')
                result = self.decision()
                self.assertEqual(result.result, 'success')
                self.assertEqual(result.source, (43608456827, 1))
                self.assertEqual(len(result.checks), 7)
        result, calls, clock, _ = self.observe(self.response_sequence())
        self.assertEqual(result.result, 'success')
        self.assertEqual(calls[2][0], 'repos/Zolmid/FlClash/actions/runs/43608456827/attempts/1/jobs?per_page=100')
        self.assertEqual(calls[1], calls[3])
        self.assertEqual(clock.sleeps, [])

    def test_old_formal_run_without_apple_check_cannot_be_reused(self):
        self.jobs['jobs'].remove(self.job('Standard CI / Apple renewal'))
        self.jobs['total_count'] -= 1
        self.assertEqual(self.decision().result, 'local')

    def test_failed_check_is_not_success(self):
        for name in reuse.CHECKS:
            with self.subTest(name=name):
                job = self.job(f'Standard CI / {name}')
                job['conclusion'] = 'failure'
                self.assertEqual(self.decision().result, 'failure')
                job['conclusion'] = 'success'

    def test_preflight_and_incomplete_checks_fall_back(self):
        for name in (reuse.PREFLIGHT, 'Standard CI / Dart'):
            job = self.job(name)
            original = copy.deepcopy(job)
            for update in ({'conclusion': 'skipped'}, {'conclusion': 'cancelled'}, {'conclusion': 'timed_out'},
                           {'conclusion': 'neutral'}, {'conclusion': None}, {'completed_at': None},
                           {'started_at': None}, {'status': 'queued', 'conclusion': None}):
                with self.subTest(name=name, update=update):
                    job.update(update)
                    self.assertEqual(self.decision().result, 'local')
                    job.update(original)
        self.job(reuse.PREFLIGHT)['conclusion'] = 'failure'
        self.assertEqual(self.decision().result, 'local')

    def test_cancelled_run_missing_duplicate_and_partial_job_pages_fall_back(self):
        self.run['conclusion'] = 'cancelled'
        self.assertEqual(self.decision().result, 'local')
        self.run['conclusion'] = 'success'
        job = self.job('Standard CI / Dart')
        self.jobs['jobs'].remove(job)
        self.jobs['total_count'] -= 1
        self.assertEqual(self.decision().result, 'local')
        self.jobs['jobs'] += [job, job]
        self.jobs['total_count'] += 2
        self.assertEqual(self.decision().result, 'local')
        self.jobs['jobs'].pop()
        self.assertEqual(self.decision().reason, 'incomplete_jobs_response')

    def test_source_identity_and_attempt_are_bound_on_run_and_every_check(self):
        for key, value in (('id', 1), ('run_attempt', 2), ('run_attempt', True), ('head_sha', 'a' * 40), ('head_branch', 'v1.1.8'),
                           ('path', '.github/workflows/build.yaml'), ('workflow_id', 1), ('event', 'workflow_dispatch'),
                           ('repository', {'id': 1, 'full_name': 'Zolmid/FlClash'}), ('head_repository', {})):
            with self.subTest(run_field=key):
                changed = {**self.run, key: value}
                self.assertEqual(reuse.decide(changed, self.jobs, event(), self.source).result, 'local')
        for name in (reuse.PREFLIGHT, *(f'Standard CI / {name}' for name in reuse.CHECKS)):
            job = self.job(name)
            for key, value in (('run_id', 1), ('run_attempt', 2), ('run_attempt', True), ('head_sha', 'a' * 40),
                               ('head_branch', 'v1.1.8'), ('id', None)):
                with self.subTest(job=name, field=key):
                    original = job[key]
                    job[key] = value
                    self.assertEqual(self.decision().result, 'local')
                    job[key] = original
        reference = self.run['referenced_workflows'][-1]
        for key, value in (('sha', 'a' * 40), ('ref', 'refs/heads/v1.1.9'), ('path', 'Other/FlClash/build.yaml')):
            original = reference[key]
            reference[key] = value
            self.assertEqual(self.decision().result, 'local')
            reference[key] = original
        self.run['referenced_workflows'] = []
        self.assertEqual(self.decision().result, 'local')

    def test_attempt_drift_during_final_readback_is_not_reused(self):
        for key, value in (('run_attempt', 2), ('head_sha', 'f' * 40), ('head_branch', 'v1.1.8'),
                           ('path', 'other.yml'), ('referenced_workflows', [])):
            with self.subTest(field=key):
                result, calls, _, _ = self.observe(self.response_sequence({**self.run, key: value}))
                self.assertEqual(result.result, 'local')
                self.assertEqual(len(calls), 4)

    def test_api_error_missing_run_and_pending_jobs_are_bounded_fallbacks(self):
        for count in range(4):
            responses = self.response_sequence()[:count] + [reuse.ApiError('api_error')]
            result, _, _, _ = self.observe(responses)
            self.assertEqual(result.result, 'local')
        result, _, clock, logs = self.observe([{'total_count': 0, 'workflow_runs': []}] * 31)
        self.assertEqual(result.reason, 'observation_timeout')
        self.assertEqual(clock.now, 900)
        self.assertEqual(clock.sleeps, [30] * 30)
        self.assertGreater(len(logs), 30)
        self.run.update(status='in_progress', conclusion=None)
        self.job('Standard CI / Dart').update(status='in_progress', conclusion=None, completed_at=None)
        responses = [self.response_sequence()[0]] + [item for _ in range(30) for item in (self.run, self.jobs)]
        result, calls, clock, _ = self.observe(responses)
        self.assertEqual(result.reason, 'observation_timeout')
        self.assertEqual(clock.now, 900)
        self.assertTrue(all(timeout <= 10 for _, timeout in calls))

    def test_waiting_can_progress_to_completed_but_never_switches_attempt(self):
        waiting = {**self.run, 'status': 'in_progress', 'conclusion': None}
        pending = {'total_count': 0, 'jobs': []}
        responses = [self.response_sequence()[0], waiting, pending, self.run, self.jobs, self.run]
        result, _, clock, _ = self.observe(responses)
        self.assertEqual(result.result, 'success')
        self.assertEqual(clock.sleeps, [30])
        responses[3] = {**self.run, 'run_attempt': 2}
        result, _, _, _ = self.observe(responses)
        self.assertEqual(result.result, 'local')
        for payload in ({'total_count': 2, 'workflow_runs': [self.run, self.run]},
                        {'total_count': 2, 'workflow_runs': [self.run]}, {}):
            self.assertEqual(self.observe([payload])[0].result, 'local')

    def test_whole_deadline_counts_api_time_and_rejects_late_success(self):
        clock, calls = Clock(), []

        def slow(path, timeout):
            calls.append(timeout)
            clock.now += 900
            return {'total_count': 1, 'workflow_runs': [self.run]}

        result = reuse.observe(event(), slow, clock, clock.sleep, lambda _: None)
        self.assertEqual(result.reason, 'observation_timeout')
        self.assertEqual(calls, [10])
        with mock.patch.object(reuse.subprocess, 'run', side_effect=subprocess.TimeoutExpired('gh', 10)):
            with self.assertRaisesRegex(reuse.ApiError, 'api_timeout'):
                reuse.read_api('unused', 10)
        for stdout, stderr, code, reason in (
                ('', 'private token (HTTP 403)', 1, 'api_http_403'),
                ('not json', '', 0, 'api_invalid_json')):
            with mock.patch.object(reuse.subprocess, 'run', return_value=subprocess.CompletedProcess('gh', code, stdout, stderr)):
                with self.assertRaisesRegex(reuse.ApiError, reason):
                    reuse.read_api('unused', 10)

    def test_non_candidates_never_poll(self):
        cases = [event(tag) for tag in ('vfoo', 'v01.2.3', 'v1.2', 'v1.2.3-rc.1', 'v1.2.3+meta',
                                        'v10000000000.2.3', 'v1.٢.3', 'v1.2.3\n')]
        cases += [event(**{key: value}) for key, value in (
            ('GITHUB_EVENT_NAME', 'workflow_dispatch'), ('GITHUB_EVENT_NAME', 'pull_request'),
            ('GITHUB_EVENT_NAME', 'workflow_call'), ('GITHUB_EVENT_NAME', 'workflow_run'),
            ('GITHUB_REPOSITORY', 'chen08209/FlClash'), ('GITHUB_REPOSITORY', 'Other/FlClash'),
            ('GITHUB_REPOSITORY_ID', ''), ('GITHUB_REPOSITORY_ID', '1'), ('GITHUB_REF_TYPE', 'branch'),
            ('GITHUB_REF', 'refs/heads/v1.1.9'), ('GITHUB_WORKFLOW_REF', ''),
            ('GITHUB_WORKFLOW_REF', 'Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/v1.1.9'),
            ('GITHUB_SERVER_URL', ''), ('GITHUB_API_URL', 'https://other.example'), ('GITHUB_SHA', ''),
            ('EVENT_DELETED', 'true'), ('EVENT_DELETED', 'null'), ('OFFICIAL_INPUT', 'true'),
            ('OFFICIAL_INPUT', 'false'), ('OFFICIAL_INPUT', ''))]
        cases += [{key: value for key, value in event().items() if key != missing} for missing in event()]
        forbidden = mock.Mock(side_effect=AssertionError('non-candidate reached API'))
        for values in cases:
            with self.subTest(values=values):
                self.assertEqual(reuse.observe(values, forbidden).result, 'local')
        self.assertFalse(reuse.candidate(event(GITHUB_SHA='0' * 40)))
        for tag in ('v0.0.0', 'v1.2.3', 'v9999999999.10.3'):
            self.assertTrue(reuse.candidate(event(tag)))

    def test_actual_yaml_cli_reports_success_failure_and_api_fallback(self):
        for scenario in ('success', 'failure', 'api_error', 'preflight_failure', 'cancelled', 'missing_job', 'attempt_drift', 'formal_call'):
            expected = scenario if scenario in ('success', 'failure') else 'local'
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                fixture = json.loads(FIXTURE.read_text())
                self.run, self.jobs = fixture['run'], fixture['jobs']
                apple = copy.deepcopy(self.job('Standard CI / Dart'))
                apple.update(name='Standard CI / Apple renewal', id=987654321)
                self.jobs['jobs'].append(apple)
                self.jobs['total_count'] += 1
                values = event()
                if scenario == 'failure':
                    self.job('Standard CI / Dart')['conclusion'] = 'failure'
                if scenario == 'preflight_failure':
                    self.job(reuse.PREFLIGHT)['conclusion'] = 'failure'
                if scenario == 'cancelled':
                    self.run['conclusion'] = 'cancelled'
                if scenario == 'missing_job':
                    self.jobs['jobs'].remove(self.job('Standard CI / Dart'))
                    self.jobs['total_count'] -= 1
                responses = self.response_sequence({**self.run, 'run_attempt': 2} if scenario == 'attempt_drift' else None)
                if scenario == 'api_error':
                    responses = [{'error': 'sensitive stderr'}]
                if scenario == 'formal_call':
                    values.update(OFFICIAL_INPUT='true',
                                  GITHUB_WORKFLOW_REF='Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/v1.1.9')
                    responses = []
                response_path = root / 'responses.json'
                response_path.write_text(json.dumps(responses))
                fake = root / 'gh'
                fake.write_text('#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\n'
                                'p=Path(os.environ["CI_TEST_RESPONSES"])\n'
                                'data=json.loads(p.read_text()); item=data.pop(0); p.write_text(json.dumps(data))\n'
                                'assert sys.argv[1:6] == ["api", "--hostname", "github.com", "--method", "GET"]\n'
                                'assert sys.argv[6].startswith("repos/Zolmid/FlClash/actions/")\n'
                                'if "error" in item: print(item["error"], file=sys.stderr); sys.exit(1)\n'
                                'print(json.dumps(item))\n')
                fake.chmod(0o755)
                env = {'PATH': str(root) + os.pathsep + os.environ['PATH'], **values,
                       'CI_TEST_RESPONSES': str(response_path), 'GITHUB_OUTPUT': str(root / 'output'),
                       'GITHUB_STEP_SUMMARY': str(root / 'summary')}
                step = next(step for step in self.build['jobs']['delegation']['steps'] if step.get('id') == 'decide')
                run = subprocess.run(['bash', '-e', '-c', step['run']], cwd=ROOT, env=env,
                                     capture_output=True, text=True, timeout=10)
                self.assertEqual(run.returncode, 1 if expected == 'failure' else 0, run.stderr)
                outputs = dict(line.split('=', 1) for line in (root / 'output').read_text().splitlines())
                self.assertEqual(outputs, {'delegated': str(expected != 'local').lower(), 'result': expected})
                self.assertNotIn('sensitive stderr', run.stdout + run.stderr)
                summary = (root / 'summary').read_text()
                self.assertIn('43608456827, attempt 1' if expected != 'local' else 'Original check conditions', summary)
                for name in CHECK_IDS:
                    self.assertEqual(check_enabled(self.build['jobs'][name]['if'], CHECK_IDS, outputs['delegated']), expected == 'local')
                if scenario == 'formal_call':
                    self.assertEqual(json.loads(response_path.read_text()), [])
                    self.assertNotIn('"api":', run.stdout)
                    self.assertIn('not_an_independent_formal_tag_push', summary)

    def test_cancellation_interrupts_owned_polling_process(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            fake = root / 'gh'
            fake.write_text('#!/bin/sh\necho \'{"total_count":0,"workflow_runs":[]}\'\n')
            fake.chmod(0o755)
            env = {'PATH': str(root) + os.pathsep + os.environ['PATH'], **event(),
                   'GITHUB_OUTPUT': str(root / 'output'), 'GITHUB_STEP_SUMMARY': str(root / 'summary')}
            with (root / 'log').open('w') as log:
                process = subprocess.Popen([sys.executable, '-u', str(ROOT / 'tool/ci/standard_ci_reuse.py')],
                                           env=env, stdout=log, stderr=subprocess.STDOUT)
                try:
                    limit = time.monotonic() + 5
                    while 'awaiting_formal_run' not in (root / 'log').read_text() and time.monotonic() < limit:
                        time.sleep(0.02)
                    self.assertIn('awaiting_formal_run', (root / 'log').read_text())
                    process.send_signal(signal.SIGTERM)
                    self.assertEqual(process.wait(timeout=5), 130)
                    self.assertIn('delegated=false', (root / 'output').read_text())
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait()

    def test_wiring_keeps_formal_checks_notes_and_permission_boundaries(self):
        jobs = self.build['jobs']
        gate = jobs['delegation']
        self.assertEqual(gate['permissions'], {'contents': 'read', 'actions': 'read'})
        self.assertEqual(gate['timeout-minutes'], 20)
        self.assertNotIn('continue-on-error', gate)
        self.assertEqual(gate['outputs'], {'delegated': '${{ steps.decide.outputs.delegated }}'})
        self.assertEqual(gate['steps'][0]['with']['persist-credentials'], False)
        step = gate['steps'][1]
        self.assertNotIn('continue-on-error', step)
        self.assertEqual(step['env'], {'GH_TOKEN': '${{ github.token }}',
                                      'EVENT_DELETED': '${{ toJSON(github.event.deleted) }}',
                                      'OFFICIAL_INPUT': '${{ toJSON(inputs.official_release) }}'})
        self.assertEqual(tuple(jobs[name]['name'] for name in (*CHECK_IDS, 'apple-renewal')), reuse.CHECKS)
        for name in CHECK_IDS:
            self.assertEqual(jobs[name]['needs'], ['delegation', 'selection'])
            self.assertIn('!cancelled()', jobs[name]['if'])
        ci = self.release['jobs']['ci']
        self.assertEqual(ci['uses'], './.github/workflows/build.yaml')
        self.assertIs(ci['with']['official_release'], True)
        self.assertEqual(ci['needs'], 'preflight')
        self.assertEqual(ci['permissions'], {'contents': 'read', 'actions': 'read'})
        self.assertEqual(self.release['jobs']['preflight']['name'], reuse.PREFLIGHT)
        self.assertEqual(self.release['concurrency'], {'group': 'zolnit-client-release', 'cancel-in-progress': False})
        self.assertIn("needs.ci.result == 'success'", self.release['jobs']['publish']['if'])
        formal = event(OFFICIAL_INPUT='true',
                       GITHUB_WORKFLOW_REF='Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/v1.1.9')
        self.assertEqual(reuse.observe(formal, mock.Mock(side_effect=AssertionError('formal call polled'))).result, 'local')
        for name in CHECK_IDS:
            self.assertTrue(check_enabled(jobs[name]['if'], CHECK_IDS, 'false'))
        dart = jobs['dart']['steps']
        for name in ('Render formal release notes', 'Upload formal release notes'):
            self.assertEqual(next(step for step in dart if step.get('name') == name)['if'], 'inputs.official_release')
        self.assertEqual(next(step for step in dart if step.get('name') == 'Upload formal release notes')['with']['name'],
                         'client-release-notes-${{ github.run_number }}')
        self.assertIn("python3 -m unittest discover -s tool/ci/tests -p '*_test.py'",
                      next(step for step in dart if step.get('name') == 'Test release helpers')['run'])


if __name__ == '__main__':
    unittest.main()
