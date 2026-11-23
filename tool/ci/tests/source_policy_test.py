import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SourcePolicyTest(unittest.TestCase):
    def test_pr_cannot_replace_selection_or_sarif_policy(self):
        root = Path(__file__).resolve().parents[3]
        cfg = json.loads(subprocess.check_output(['ruby', '-ryaml', '-rjson', '-e',
            'puts JSON.generate(YAML.safe_load(File.read(ARGV[0]), aliases: true))',
            str(root / '.github/workflows/source-analysis.yml')], text=True))
        loaders = [next(s for s in cfg['jobs'][j]['steps'] if s.get('id') == 'policy')['run']
                   for j in ('scope', 'codeql')]
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
