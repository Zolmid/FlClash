import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import review_sarif


class SarifReviewTest(unittest.TestCase):
    def test_only_high_primary_locations_on_changed_lines_block(self):
        rules = [{'id': rule, 'properties': {'security-severity': severity}}
                 for rule, severity in [('old', '8.0'), ('new', '7.0'), ('low', '3.0')]]
        findings = [{'ruleId': rule, 'locations': [{'physicalLocation': {
            'artifactLocation': {'uri': 'code%20with%20spaces.py'}, 'region': {'startLine': line}}}]}
                    for rule, line in [('old', 2), ('new', 7), ('low', 7)]]
        data = {'version': '2.1.0', 'runs': [{'tool': {'driver': {'name': 'CodeQL'},
                'extensions': [{'rules': rules}]}, 'results': findings}]}
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'results.sarif'
            path.write_text(json.dumps(data))
            with patch.object(review_sarif, 'additions', return_value=[(7, 9)]):
                self.assertEqual(review_sarif.review([path], 'base', 'head'),
                                 (3, 2, {('new', 'code with spaces.py', 7)}))
                self.assertEqual(review_sarif.review([path], None, 'head'), (3, 2, set()))
            with self.assertRaises(ValueError):
                review_sarif.review([], 'base', 'head')

    def test_diff_hunks_exclude_removed_lines(self):
        diff = b'@@ -5,2 +4,0 @@\n-deleted\n@@ -9 +9,3 @@\n+one\n+two\n+three\n@@ -18 +20 @@\n+changed\n'
        with patch.object(subprocess, 'check_output', return_value=diff) as run:
            self.assertEqual(review_sarif.additions('a', 'b', 'odd ? name.py'), [(9, 11), (20, 20)])
            self.assertEqual(run.call_args.args[0][-1], ':(literal)odd ? name.py')
