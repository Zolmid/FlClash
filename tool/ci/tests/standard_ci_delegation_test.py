import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / '.github/workflows/build.yaml'
RELEASE = ROOT / '.github/workflows/client-release.yml'
CHECKS = ('dart', 'plugins', 'go', 'android', 'rust', 'windows-helper-test')


def workflow(path):
    code = "require 'yaml'; require 'json'; puts JSON.generate(YAML.respond_to?(:unsafe_load_file) ? YAML.unsafe_load_file(ARGV[0]) : YAML.load_file(ARGV[0]))"
    return json.loads(subprocess.check_output(['ruby', '-e', code, str(path)], text=True))


def event(tag='v1.2.3', **changes):
    ref = f'refs/tags/{tag}'
    data = {'GITHUB_EVENT_NAME': 'push', 'GITHUB_REPOSITORY': 'Zolmid/FlClash',
            'GITHUB_REPOSITORY_ID': '1420254999', 'GITHUB_REF_TYPE': 'tag',
            'GITHUB_REF': ref, 'GITHUB_REF_NAME': tag,
            'GITHUB_WORKFLOW_REF': f'Zolmid/FlClash/.github/workflows/build.yaml@{ref}',
            'EVENT_DELETED': 'false', 'OFFICIAL_INPUT': 'null'}
    data.update(changes)
    return data


class DelegationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = workflow(BUILD)
        cls.release = workflow(RELEASE)
        cls.script = cls.build['jobs']['delegation']['steps'][0]['run']

    def decide(self, values):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'output'
            summary = Path(temp) / 'summary'
            env = {'PATH': os.environ['PATH'], 'GITHUB_OUTPUT': str(output),
                   'GITHUB_STEP_SUMMARY': str(summary), **values}
            result = subprocess.run(['bash', '-eu', '-c', self.script], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return output.read_text(), summary.read_text() if summary.exists() else ''

    def test_event_matrix(self):
        for tag in ('v0.0.0', 'v1.2.3', 'v9999999999.10.3'):
            with self.subTest(tag=tag):
                output, summary = self.decide(event(tag))
                self.assertEqual(output, 'delegated=true\n')
                self.assertIn('does not report their result', summary)
        cases = [event(tag) for tag in ('vfoo', 'v01.2.3', 'v1.2', 'v1.2.3-rc.1',
                                        'v1.2.3+meta', 'v10000000000.2.3')]
        cases += [event(**{key: value}) for key, value in (
            ('GITHUB_EVENT_NAME', 'workflow_dispatch'), ('GITHUB_EVENT_NAME', 'pull_request'),
            ('GITHUB_EVENT_NAME', 'workflow_call'), ('GITHUB_REPOSITORY', 'chen08209/FlClash'),
            ('GITHUB_REPOSITORY', 'Other/FlClash'), ('GITHUB_REPOSITORY_ID', ''),
            ('GITHUB_REPOSITORY_ID', '1'), ('GITHUB_REF_TYPE', 'branch'),
            ('GITHUB_REF', 'refs/heads/v1.2.3'), ('GITHUB_REF_NAME', ''),
            ('GITHUB_WORKFLOW_REF', ''),
            ('GITHUB_WORKFLOW_REF', 'Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/v1.2.3'),
            ('EVENT_DELETED', 'true'), ('EVENT_DELETED', 'null'), ('OFFICIAL_INPUT', 'true'),
            ('OFFICIAL_INPUT', 'false'), ('OFFICIAL_INPUT', ''))]
        cases.append(event(GITHUB_WORKFLOW_REF='Zolmid/FlClash/.github/workflows/other.yml@refs/tags/v1.2.3'))
        for values in cases:
            with self.subTest(values=values):
                self.assertEqual(self.decide(values), ('delegated=false\n', ''))

    def test_workflow_wiring_and_release_consumer(self):
        jobs = self.build['jobs']
        condition = "${{ !cancelled() && needs.delegation.outputs.delegated != 'true' && (github.event_name == 'workflow_dispatch' || !github.event.repository.private || inputs.official_release) }}"
        for name in CHECKS:
            with self.subTest(job=name):
                self.assertEqual(jobs[name]['needs'], 'delegation')
                self.assertEqual(jobs[name]['if'], condition)
        self.assertEqual(jobs['delegation']['permissions'], {})
        gate = jobs['delegation']
        self.assertEqual(gate['outputs']['delegated'], '${{ steps.decide.outputs.delegated }}')
        self.assertEqual(gate['steps'][0]['env'], {
            'EVENT_DELETED': '${{ toJSON(github.event.deleted) }}',
            'OFFICIAL_INPUT': '${{ toJSON(inputs.official_release) }}',
        })
        ci = self.release['jobs']['ci']
        self.assertEqual(ci['uses'], './.github/workflows/build.yaml')
        self.assertIs(ci['with']['official_release'], True)
        self.assertEqual(ci['needs'], 'preflight')
        self.assertIn('needs.ci.result == \'success\'', self.release['jobs']['publish']['if'])
        dart = jobs['dart']['steps']
        for name in ('Render formal release notes', 'Upload formal release notes'):
            self.assertEqual(next(step for step in dart if step.get('name') == name)['if'], 'inputs.official_release')
        self.assertEqual(next(step for step in dart if step.get('name') == 'Upload formal release notes')['with']['name'],
                         'client-release-notes-${{ github.run_number }}')


if __name__ == '__main__':
    unittest.main()
