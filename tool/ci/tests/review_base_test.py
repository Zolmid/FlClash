import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from review_base import comparison_base


class ReleaseBaselineTest(unittest.TestCase):
    def test_selects_reachable_lower_stable_tag_from_formal_caller(self):
        with tempfile.TemporaryDirectory() as tmp:
            def git(*args):
                return subprocess.check_output(['git', '-C', tmp, '-c', 'user.name=CI',
                                                '-c', 'user.email=ci@example.invalid', *args], text=True).strip()
            git('init', '-q', '-b', 'main')
            git('commit', '-qm', 'first', '--allow-empty')
            git('tag', 'v1.1.9')
            git('commit', '-qm', 'release', '--allow-empty')
            previous = git('rev-parse', 'HEAD')
            git('tag', '-a', 'v1.1.10', '-m', 'stable')
            git('commit', '-qm', 'next', '--allow-empty')
            git('tag', 'v1.1.11-rc.1')
            git('tag', 'v1.1.12')
            head = git('rev-parse', 'HEAD')
            git('switch', '-qc', 'other')
            git('commit', '-qm', 'unrelated lower tag', '--allow-empty')
            git('tag', 'v1.1.11')
            env = {'GITHUB_REF_NAME': 'v1.1.12', 'GITHUB_REF_TYPE': 'tag', 'GITHUB_SHA': head,
                   'GITHUB_REPOSITORY': 'Zolmid/FlClash',
                   'GITHUB_WORKFLOW_REF': 'Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/v1.1.12'}
            cwd = os.getcwd()
            try:
                os.chdir(tmp)
                self.assertEqual(comparison_base(env), previous)
                self.assertEqual(comparison_base({**env, 'GITHUB_WORKFLOW_REF': 'another-workflow'}), '')
            finally:
                os.chdir(cwd)
