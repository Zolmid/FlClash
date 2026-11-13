from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
SECRETS = {
    'MACOS_DEVELOPER_ID_P12_BASE64', 'MACOS_DEVELOPER_ID_P12_PASSWORD',
    'APPLE_ASC_API_KEY_ID', 'APPLE_ASC_ISSUER_ID', 'APPLE_ASC_P8_BASE64',
}
API_SECRETS = {name for name in SECRETS if name.startswith('APPLE_')}


def block(text, name, indent):
    lines = text.splitlines()
    header = ' ' * indent + name + ':'
    start = lines.index(header) + 1
    end = start
    while end < len(lines):
        line = lines[end]
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        end += 1
    return '\n'.join(lines[start:end])


class MacOSWorkflowTest(unittest.TestCase):
    def test_caller_and_callee_require_only_five_named_secrets(self):
        pipeline = (ROOT / '.github/workflows/macos-notarization-pipeline.yml').read_text()
        declared = block(block(pipeline, 'workflow_call', 2), 'secrets', 4)
        self.assertEqual(set(re.findall(r'^      ([A-Z0-9_]+):$', declared, re.M)), SECRETS)
        for name in SECRETS:
            self.assertEqual(block(declared, name, 6).strip(), 'required: true')
        for filename, job in (('client-release.yml', 'macos-sign'), ('macos-notarization-verify.yml', 'verify')):
            with self.subTest(caller=filename):
                caller = (ROOT / '.github/workflows' / filename).read_text()
                job_text = block(caller, job, 2)
                mapping = block(job_text, 'secrets', 4)
                pairs = dict(re.findall(r'^      ([A-Z0-9_]+): (.+)$', mapping, re.M))
                self.assertEqual(set(pairs), SECRETS)
                self.assertEqual(pairs, {name: '${{ secrets.' + name + ' }}' for name in SECRETS})
                self.assertNotIn('secrets: inherit', job_text)
                self.assertNotIn('environment:', job_text)

    def test_every_concrete_job_keeps_environment_and_least_secret_exposure(self):
        pipeline = (ROOT / '.github/workflows/macos-notarization-pipeline.yml').read_text()
        for job in ('submit-app', 'wait-app', 'submit-dmg', 'wait-dmg', 'finalize'):
            with self.subTest(job=job):
                body = block(pipeline, job, 2)
                self.assertIn('    environment: macos-distribution', body)
                names = set(re.findall(r'\$\{\{ secrets\.([A-Z0-9_]+) \}\}', body))
                self.assertEqual(names, API_SECRETS if job.startswith('wait-') else SECRETS)
                self.assertIn('MACOS_TEAM_ID: ${{ vars.MACOS_TEAM_ID }}', body)


if __name__ == '__main__':
    unittest.main()
