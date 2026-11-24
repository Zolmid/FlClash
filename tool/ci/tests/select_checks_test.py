import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import select_checks as selector
from standard_ci_delegation_test import CHECK_IDS, check_enabled, event as formal_event, workflow

ALL = (*CHECK_IDS, 'desktop', 'apple-renewal')
NORMAL = (*CHECK_IDS, 'desktop')
TAG_CHECKS = (*CHECK_IDS, 'apple-renewal')
ZOLMID = {'private': False, 'full_name': 'Zolmid/FlClash', 'id': 1420254999}
UPSTREAM = {'private': False, 'full_name': 'chen08209/FlClash', 'id': 1}
FEATURE = 'refs/heads/feature'
MAIN = 'refs/heads/main'
TAG = 'refs/tags/v1.2.3'
PR = 'refs/pull/17/merge'
SELECTOR = 'tool/ci/select_checks.py'
DOC = 'docs/maintenance/ci-release-and-recovery.md'


def step(job, step_id):
    return next(item for item in job['steps'] if item.get('id') == step_id)


class SelectionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs = workflow('build.yaml')['jobs']
        cls.bootstrap = step(cls.jobs['selection'], 'select')['run']

    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.tmp = Path(directory.name)
        self.repo = self.tmp / 'repo'
        self.repo.mkdir()
        self.addCleanup(os.chdir, os.getcwd())
        os.chdir(self.repo)
        self.git('init', '--quiet', '-b', 'main')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'CI test')
        self.write('lib/code.dart')
        self.write(DOC)
        self.base = self.commit()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), '-c', 'core.hooksPath=/dev/null',
                                        '-c', 'commit.gpgSign=false', *args], text=True).strip()

    def write(self, path, data='fixture'):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '--quiet', '-m', 'fixture')
        return self.git('rev-parse', 'HEAD')

    def push(self, head, ref=FEATURE, repository=ZOLMID, **changes):
        return {'ref': ref, 'before': self.base, 'after': head, 'created': False, 'deleted': False,
                'forced': False, 'repository': repository, **changes}

    def merge_pr(self):
        topic = self.git('rev-parse', 'HEAD')
        self.git('switch', '--quiet', '--detach', self.base)
        self.git('merge', '--quiet', '--no-ff', '-m', 'test merge', topic)
        event = {'number': 17, 'repository': ZOLMID, 'pull_request': {
            'base': {'sha': self.base, 'repo': ZOLMID}, 'head': {'sha': topic, 'repo': {'id': 2}}}}
        return self.git('rev-parse', 'HEAD'), event

    def assert_jobs(self, kind, expected, name, ref, event, head, official=False, called=False):
        profile, selection = selector.select(name, ref, event, head, official, called)
        self.assertEqual(kind, profile)
        selected = {job for job in selection if selection[job]}
        actual = {job for job in ALL if check_enabled(self.jobs[job]['if'], selected)}
        self.assertEqual(set(expected), actual)

    def test_main_docs_and_event_matrix(self):
        self.write(DOC, 'documentation edit')
        head = self.commit()
        for ref in (FEATURE, MAIN):
            self.assert_jobs('docs', (), 'push', ref, self.push(head, ref), head)
        for event in ('workflow_dispatch', 'workflow_call', 'merge_group'):
            self.assert_jobs('full', NORMAL, event, MAIN, self.push(head, MAIN), head)
        self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head, called=True)
        self.assert_jobs('full', TAG_CHECKS, 'push', TAG, self.push(head, TAG), head)
        private = dict(ZOLMID, private=True)
        self.assert_jobs('full', TAG_CHECKS, 'push', TAG, self.push(head, TAG, private), head, official=True)
        self.assert_jobs('docs', (), 'push', FEATURE, self.push(head, repository=private), head)
        self.assert_jobs('full', NORMAL, 'workflow_dispatch', MAIN, self.push(head, MAIN, private), head)
        self.assert_jobs('full', NORMAL, 'push', MAIN, self.push(head, MAIN, UPSTREAM), head)
        self.assert_jobs('full', TAG_CHECKS, 'push', TAG, self.push(head, TAG, UPSTREAM), head)
        self.assert_jobs('full', NORMAL, 'push', MAIN, self.push(head, MAIN, dict(ZOLMID, id=2)), head)
        special = 'refs/heads/codex/native-client-shared'
        self.assert_jobs('full', NORMAL, 'push', special, self.push(head, special), head)
        self.git('tag', 'v1.2.3', head)
        self.assert_jobs('docs', (), 'push', MAIN, self.push(head, MAIN), head)
        verify = next(s for s in self.jobs['selection']['steps'] if s.get('name') == 'Verify changelog on main documentation changes')
        self.assertIn("github.ref == 'refs/heads/main'", verify['if'])
        self.assertIn("steps.select.outputs.profile == 'docs'", verify['if'])
        self.assertIn('dart run tool/changelog.dart verify', verify['run'])
        merge, pr = self.merge_pr()
        self.assert_jobs('docs', (), 'pull_request', PR, pr, merge)
        pr['pull_request']['base']['repo'] = UPSTREAM
        self.assert_jobs('full', NORMAL, 'pull_request', PR, pr, merge)

    def test_only_registered_android_unit_sources_narrow(self):
        self.write('android/tests/common/EnumsTest.kt')
        head = self.commit()
        self.assert_jobs('android-tests', ('android',), 'push', FEATURE, self.push(head), head)
        self.assert_jobs('full', NORMAL, 'push', MAIN, self.push(head, MAIN), head)
        merge, pr = self.merge_pr()
        self.assert_jobs('android-tests', ('android',), 'pull_request', PR, pr, merge)
        pr['pull_request']['head']['sha'] = self.base
        self.assert_jobs('full', NORMAL, 'pull_request', PR, pr, merge)

    def test_release_and_shared_or_unknown_paths_run_full(self):
        for path in ('CHANGELOG.md', 'pubspec.yaml', '.github/workflows/build.yaml', 'docs/release.md',
                     'test/android/shared_test.dart', 'test/core/routing.go', 'android/unknown/FooTest.kt',
                     'ios/Shared/TunnelIntentClient.swift', 'tool/acceptance/ios_intents/run_race.sh',
                     'core/api.go', 'plugins/example.dart', 'tool/build.py', 'unknown\nREADME.md'):
            with self.subTest(path=path):
                self.write(path)
                head = self.commit()
                self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head)
                self.base = head

    def test_modes_renames_and_history_uncertainty(self):
        Path('lib/code.dart').rename('README.md')
        head = self.commit()
        self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head)
        self.base = head
        Path(DOC).unlink()
        head = self.commit()
        self.assert_jobs('docs', (), 'push', MAIN, self.push(head, MAIN), head)
        self.base = head
        Path(DOC).symlink_to('../../README.md')
        head = self.commit()
        self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head)
        self.base = head
        Path(DOC).unlink()
        self.write(DOC)
        head = self.commit()
        self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head)
        self.base = head
        self.write('docs/maintenance/spaces and\nnewline.md')
        head = self.commit()
        self.assert_jobs('docs', (), 'push', FEATURE, self.push(head), head)
        for changes in ({'before': '0' * 40}, {'before': 'f' * 40}, {'after': self.base}, {'deleted': True},
                        {'before': '--help'}, {'before': None}, {'forced': True}, {'created': True}):
            self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head, **changes), head)
        self.assertIsNone(selector.changed_paths(head, self.base))

    def test_partial_or_oversize_comparisons(self):
        self.assertIsNone(selector.raw_paths(b':100644 100644 111 222 M\0README.md'))
        for n in range(selector.MAX_PATHS + 1):
            self.write(f'docs/maintenance/guide{n}.md')
        head = self.commit()
        self.assert_jobs('full', NORMAL, 'push', FEATURE, self.push(head), head)
        self.assertIsNone(selector.raw_paths(b'x' * selector.MAX_DIFF_BYTES + b'\0'))

    def bootstrap_pr(self, merge, event, base):
        event_file, output = self.tmp / 'event', self.tmp / 'output'
        event_file.write_text(json.dumps(event))
        output.write_text('')
        env = {'PATH': os.environ['PATH'], 'GITHUB_EVENT_PATH': str(event_file), 'RUNNER_TEMP': str(self.tmp),
               'GITHUB_WORKSPACE': str(self.repo), 'GITHUB_OUTPUT': str(output), 'GITHUB_EVENT_NAME': 'pull_request',
               'GITHUB_REF': PR, 'BASE_SHA': base, 'GITHUB_SHA': merge, 'OFFICIAL_INPUT': 'null'}
        run = subprocess.run(['bash', '-eu', '-c', self.bootstrap], env=env, capture_output=True, text=True)
        return run.returncode, dict(line.split('=', 1) for line in output.read_text().splitlines())

    def test_trusted_base_and_first_adoption_never_run_pr_selector(self):
        self.write(SELECTOR, "raise SystemExit('PR selector ran')\n")
        self.commit()
        merge, pr = self.merge_pr()
        full = {job.replace('-', '_'): 'true' for job in NORMAL}
        full['apple_renewal'] = 'false'
        self.assertEqual(self.bootstrap_pr(merge, pr, self.base), (0, dict(full, profile='full')))
        self.write(SELECTOR, Path(selector.__file__).read_text())
        self.base = self.commit()
        self.write(SELECTOR, "raise SystemExit('PR selector ran')\n")
        self.commit()
        merge, pr = self.merge_pr()
        self.assertEqual(self.bootstrap_pr(merge, pr, self.base), (0, dict(full, profile='full')))
        for bad in ('', '0' * 40, 'f' * 40, 'bad ref', pr['pull_request']['head']['sha']):
            status, outputs = self.bootstrap_pr(merge, pr, bad)
            self.assertNotEqual(status, 0)
            self.assertFalse(outputs)
        self.base = pr['pull_request']['base']['sha']
        self.git('switch', '--quiet', '--detach', self.base)
        self.write(DOC, 'allowed')
        self.commit()
        merge, pr = self.merge_pr()
        status, outputs = self.bootstrap_pr(merge, pr, self.base)
        self.assertEqual((status, outputs['profile']), (0, 'docs'))
        self.assertEqual(set(outputs.values()), {'false', 'docs'})


class GateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = workflow('build.yaml')
        cls.jobs = cls.build['jobs']
        cls.script = cls.jobs['ci-gate']['steps'][0]['run']

    def gate(self, needs):
        run = subprocess.run(['bash', '-e', '-c', self.script], capture_output=True,
                             env={'PATH': os.environ['PATH'], 'NEEDS_JSON': json.dumps(needs)})
        return run.returncode == 0

    def fixture(self, selected, observer='skipped'):
        observed = observer in ('success', 'failure')
        jobs = {job: {'result': 'success' if job in selected and (job == 'desktop' or not observed) else 'skipped'}
                for job in ALL}
        outputs = {job.replace('-', '_'): str(job in selected).lower() for job in ALL}
        outputs['observe'] = str(observer != 'skipped').lower()
        jobs['selection'] = {'result': 'success', 'outputs': outputs}
        jobs['review'] = {'result': 'success'}
        jobs['delegation'] = {'result': {'local': 'success'}.get(observer, observer),
                              'outputs': {} if observer == 'skipped' else {'delegated': str(observed).lower()}}
        return jobs

    def test_actual_gate_for_full_docs_android_and_formal_results(self):
        for selected, observer in ((NORMAL, 'skipped'), ((), 'skipped'), (('android',), 'skipped'),
                                   (TAG_CHECKS, 'success'), (TAG_CHECKS, 'local')):
            self.assertTrue(self.gate(self.fixture(selected, observer)))
        self.assertFalse(self.gate(self.fixture(TAG_CHECKS, 'failure')))
        for job in (*NORMAL, 'selection', 'review'):
            for state in ('failure', 'cancelled', 'skipped', None):
                jobs = self.fixture(NORMAL)
                if state is None:
                    del jobs[job]
                else:
                    jobs[job]['result'] = state
                self.assertFalse(self.gate(jobs), (job, state))
        for state in ('failure', 'cancelled', 'skipped', None):
            jobs = self.fixture(TAG_CHECKS, 'local')
            if state is None:
                del jobs['apple-renewal']
            else:
                jobs['apple-renewal']['result'] = state
            self.assertFalse(self.gate(jobs))
        for observer, job, state in (('success', 'dart', 'success'), ('local', 'dart', 'skipped'),
                                     ('success', 'review', 'skipped'), ('success', 'delegation', 'cancelled'),
                                     ('success', 'delegation', 'skipped'), ('skipped', 'delegation', 'success')):
            jobs = self.fixture(TAG_CHECKS, observer)
            jobs[job]['result'] = state
            self.assertFalse(self.gate(jobs))
        jobs = self.fixture((), 'skipped')
        jobs['dart']['result'] = 'success'
        self.assertFalse(self.gate(jobs))
        jobs = self.fixture(TAG_CHECKS, 'success')
        del jobs['delegation']
        self.assertFalse(self.gate(jobs))
        jobs = self.fixture(NORMAL)
        del jobs['selection']['outputs']['dart']
        self.assertFalse(self.gate(jobs))

    def test_triggers_permissions_and_publisher_contract(self):
        triggers = self.build.get('on', self.build.get('true'))
        self.assertIn('pull_request', triggers)
        self.assertNotIn('pull_request_target', triggers)
        self.assertEqual(triggers['merge_group']['types'], ['checks_requested'])
        self.assertNotIn('permissions', self.build)
        self.assertNotIn('permissions', self.jobs['upload'])
        for name, job in self.jobs.items():
            if name in ('delegation', 'upload'):
                continue
            self.assertEqual(job['permissions'], {'contents': 'read'}, name)
        for name in (*ALL, 'selection', 'delegation'):
            job = self.jobs[name]
            self.assertNotIn('secrets', json.dumps(job))
            for entry in job['steps']:
                if entry.get('uses', '').split('@')[0] == 'actions/checkout':
                    self.assertIs(entry['with']['persist-credentials'], False)
        for name in ('build', 'upload'):
            condition = self.jobs[name]['if']
            for guard in ("github.repository == 'chen08209/FlClash'", "github.event_name == 'push'",
                          "startsWith(github.ref, 'refs/tags/v')"):
                self.assertIn(guard, condition)
        self.assertEqual(self.jobs['upload']['needs'], 'build')
        self.assertIn("needs.build.result == 'success'", self.jobs['upload']['if'])
        for required in ('ci-gate', *CHECK_IDS):
            self.assertIn(required, self.jobs['build']['needs'])
            self.assertIn(f"needs.{required}.result == 'success'", self.jobs['build']['if'])
        self.assertEqual(set(self.jobs['ci-gate']['needs']), {*ALL, 'selection', 'review', 'delegation'})
        self.assertEqual(self.jobs['ci-gate']['name'],
                         "${{ (github.event_name == 'pull_request' || github.event_name == 'merge_group') "
                         "&& 'CI gate' || 'Build gate' }}")
        self.assertEqual(self.jobs['review']['uses'], './.github/workflows/repository-review.yml')
        self.assertIn("github.event_name == 'push'", self.jobs['delegation']['if'])
        self.assertIn("needs.selection.outputs.observe == 'true'", self.jobs['delegation']['if'])
        self.assertIn("github.event_name != 'pull_request'", self.build['env']['BRANCH_CACHE'])
        setup = next(s for s in self.jobs['android']['steps'] if s.get('id') == 'android-tools')
        self.assertEqual(setup['uses'], './.github/actions/android-check-setup')
        self.assertEqual(setup['with']['cache'], '${{ env.BRANCH_CACHE }}')
        composite = workflow('../actions/android-check-setup/action.yml')
        gradle = next(s for s in composite['runs']['steps']
                      if s.get('uses', '').startswith('gradle/actions/setup-gradle@'))
        self.assertEqual(gradle['with']['cache-disabled'], "${{ inputs.cache != 'true' }}")

    def test_full_jobs_check_tracked_locks_generators_and_ios(self):
        dart = [step.get('run', '') for step in self.jobs['dart']['steps']]
        check = dart.index('dart run build_runner build --only-check')
        self.assertLess(dart.index('flutter pub get --enforce-lockfile'), check)
        self.assertLess(next(i for i, line in enumerate(dart) if 'setup.build_assets = false' in line), check)
        repo = Path(selector.__file__).parents[2]
        for job in ('rust', 'windows-helper-test'):
            commands = [line for s in self.jobs[job]['steps'] for line in s.get('run', '').splitlines()
                        if line.startswith('cargo test ')]
            self.assertTrue(commands)
            for command in commands:
                tokens = command.split()
                self.assertIn('--locked', tokens)
                self.assertTrue((repo / tokens[tokens.index('--manifest-path') + 1]).with_name('Cargo.lock').is_file())
        ios = next(s for s in self.jobs['desktop']['steps'] if s.get('name') == 'Check iOS tunnel lifecycle')
        self.assertIn("matrix.platform == 'macos'", ios['if'])
        self.assertIn("github.event_name == 'pull_request'", ios['if'])
        self.assertIn("github.event_name == 'merge_group'", ios['if'])
        self.assertIn('!inputs.official_release', ios['if'])
        self.assertIn('tool/acceptance/ios_intents/check_sdk.sh', ios['run'])
        self.assertIn('race classifier completion abandon', ios['run'])
        self.assertIn('GITHUB_SHA', ios['run'])
        apple = self.jobs['apple-renewal']
        self.assertEqual(apple['steps'][0]['with']['ref'], '${{ github.sha }}')
        self.assertIn('run_classifier.sh', apple['steps'][1]['run'])
        self.assertIn('GITHUB_SHA', apple['steps'][1]['run'])

    def test_apple_step_invokes_classifier_and_propagates_failure(self):
        script = self.jobs['apple-renewal']['steps'][1]['run']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tool/acceptance/ios_intents').mkdir(parents=True)
            classifier = root / 'tool/acceptance/ios_intents/run_classifier.sh'
            classifier.write_text('echo invoked > "$GITHUB_WORKSPACE/invoked"\nexit "$RESULT"\n')
            for name, body in {
                'git': 'echo "${CHECKOUT_SHA:-$GITHUB_SHA}"',
                'sudo': 'exit 0',
                'xcrun': 'if [[ "$*" == *--show-sdk-version* ]]; then echo 27.1; else echo /sdk; fi',
            }.items():
                binary = root / name
                binary.write_text('#!/bin/bash\n' + body + '\n')
                binary.chmod(0o755)
            for result in ('0', '7'):
                (root / 'invoked').unlink(missing_ok=True)
                env = {'PATH': str(root) + os.pathsep + os.environ['PATH'], 'GITHUB_WORKSPACE': str(root),
                       'GITHUB_SHA': 'a' * 40, 'RESULT': result}
                run = subprocess.run(['bash', '-e', '-c', script], cwd=root, env=env, capture_output=True)
                self.assertEqual(run.returncode, int(result))
                self.assertTrue((root / 'invoked').exists())
            (root / 'invoked').unlink()
            env['CHECKOUT_SHA'] = 'wrong-sha'
            self.assertNotEqual(subprocess.run(['bash', '-e', '-c', script], cwd=root, env=env,
                                               capture_output=True).returncode, 0)
            self.assertFalse((root / 'invoked').exists())

    def test_release_builds_and_publish_depend_on_standard_ci(self):
        release = workflow('client-release.yml')['jobs']
        self.assertIn('ci', release['builds']['needs'])
        self.assertIn('ci', release['macos-sign']['needs'])
        self.assertIn("needs.ci.result == 'success'", release['publish']['if'])
        self.assertIs(release['ci']['with']['official_release'], True)

    def test_exact_observer_eligibility_step_without_token(self):
        candidate = step(self.jobs['selection'], 'candidate')
        self.assertNotIn('GH_TOKEN', candidate['env'])
        for changes, expected in (({}, True), ({'GITHUB_EVENT_NAME': 'pull_request'}, False),
                                  ({'GITHUB_REPOSITORY_ID': '1'}, False), ({'OFFICIAL_INPUT': 'true'}, False),
                                  ({'EVENT_DELETED': 'true'}, False), ({'GITHUB_REF_NAME': 'v1.2.3-rc1'}, False)):
            with tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / 'out'
                env = {'PATH': os.environ['PATH'], 'GITHUB_OUTPUT': str(output), **formal_event(**changes)}
                subprocess.run(['bash', '-e', '-c', candidate['run']], cwd=Path(selector.__file__).parents[2],
                               env=env, check=True)
                self.assertEqual(output.read_text().strip(), f'observe={str(expected).lower()}')


if __name__ == '__main__':
    unittest.main()
