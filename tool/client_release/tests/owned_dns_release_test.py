import json
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import assemble_release as release

ROOT = Path(__file__).resolve().parents[3]

class OwnedDnsReleaseTest(unittest.TestCase):
    def test_formal_sdk_gate_is_explicit_and_cannot_mistake_relay_for_sdk(self):
        with self.assertRaisesRegex(release.ReleaseError, 'MOBILE_DNS_SDK_PRODUCTION_BLOCKED'):
            release.check_owned_dns_release(ROOT)

    def test_cloud_build_and_archive_define_are_the_same_strict_policy(self):
        source = (ROOT / 'packages/zolnit_client/lib/src/owned_dns_config.dart').read_text()
        value = re.search(r"r'([^']+)'", source).group(1)
        self.assertIs(json.loads(value)['strict'], True)
        workflow = (ROOT / '.github/workflows/cloud-build.yml').read_text()
        self.assertEqual(workflow.count("'" + value + "'"), 2)
        commands = [line for line in workflow.splitlines() if 'flutter build' in line and 'ZOLNIT_CLIENT_BUNDLE=' in line]
        self.assertGreaterEqual(len(commands), 3)
        self.assertTrue(all('--dart-define=ZOLNIT_OWNED_DNS=' in line for line in commands))
        self.assertEqual(workflow.count("echo 'owned_dns=strict-v1'"), 2)

if __name__ == '__main__':
    unittest.main()
