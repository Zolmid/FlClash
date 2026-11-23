import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SourcePolicyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(__file__).resolve().parents[3]
        workflow = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
            'puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))',
            str(cls.root / '.github/workflows/source-analysis.yml')], text=True))
        cls.jobs = workflow['jobs']

    def test_pr_cannot_replace_selection_or_sarif_policy(self):
        loaders = [next(s for s in self.jobs[j]['steps'] if s.get('id') == 'policy')['run']
                   for j in ('scope', 'adjudicate')]
        self.assertEqual(*loaders)
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp) / 'repo'
            work.mkdir()
            git = lambda *args: subprocess.check_output(['git', '-C', str(work), '-c', 'user.name=CI',
                '-c', 'user.email=ci@example.invalid', *args], text=True).strip()
            git('init', '-q')
            policy = work / 'tool/ci'
            policy.mkdir(parents=True)
            names = ('select_checks.py', 'security_languages.py', 'review_base.py', 'review_sarif.py')
            for name in names:
                (policy / name).write_text('trusted\n')
            git('add', 'tool')
            git('commit', '-qm', 'base')
            base = git('rev-parse', 'HEAD')
            for name in names:
                (policy / name).write_text('proposed\n')
            git('commit', '-qam', 'proposed')
            env_file = Path(tmp) / 'env'
            subprocess.run(['bash', '-c', loaders[0]], cwd=work, check=True,
                           env=dict(os.environ, BASE_SHA=base, GITHUB_SHA=git('rev-parse', 'HEAD'),
                                    GITHUB_EVENT_NAME='pull_request', RUNNER_TEMP=tmp, GITHUB_ENV=str(env_file)))
            loaded = Path(env_file.read_text().strip().split('=', 1)[1])
            for name in names:
                self.assertEqual((loaded / name).read_text(), 'trusted\n')
                self.assertEqual((policy / name).read_text(), 'proposed\n')

    def test_separate_review_runner_requires_every_report_from_this_attempt(self):
        job = self.jobs['adjudicate']
        self.assertEqual(job['needs'], ['scope', 'codeql'])
        self.assertEqual([step.get('id') or step['uses'].split('@')[0] for step in job['steps']],
                         ['actions/checkout', 'policy', 'actions/download-artifact', 'review'])
        self.assertFalse(any('review_sarif.py' in step.get('run', '') for step in self.jobs['codeql']['steps']))
        self.assertEqual(job['steps'][2]['with']['pattern'], 'codeql-*-${{ github.run_id }}-${{ github.run_attempt }}')
        report = {'version': '2.1.0', 'runs': [{'tool': {'driver': {'name': 'CodeQL'}}, 'results': []}]}
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            env = dict(os.environ, BASE_SHA='', GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_SHA='a'*40,
                       GITHUB_RUN_ID='12', GITHUB_RUN_ATTEMPT='2', LANGUAGES='["go","rust"]', RUNNER_TEMP=tmp,
                       SOURCE_POLICY=str(self.root / 'tool/ci'), GITHUB_STEP_SUMMARY=str(root / 'summary'))
            def review():
                return subprocess.run(['bash', '-c', job['steps'][-1]['run']], env=env,
                                      capture_output=True, text=True).returncode
            def add(language, attempt):
                directory = root / 'codeql-reports' / f'codeql-{language}-12-{attempt}'
                directory.mkdir(parents=True)
                path = directory / 'report.sarif'
                path.write_text(json.dumps(report))
                return path
            add('go', 2)
            add('rust', 1)
            self.assertNotEqual(review(), 0)
            current = add('rust', 2)
            self.assertEqual(review(), 0)
            current.write_text('{}')
            self.assertNotEqual(review(), 0)
