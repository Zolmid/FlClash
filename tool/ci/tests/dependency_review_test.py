import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import dependency_review as review
from security_languages import ALL, languages


def report(version, advisory=None):
    return {'results': [{'source': {'path': 'services/helper/Cargo.lock'}, 'packages': [{
        'package': {'name': 'sample', 'version': version, 'ecosystem': 'crates.io'},
        'vulnerabilities': [] if advisory is None else [{'id': advisory}],
    }]}]}


class DependencyReviewTest(unittest.TestCase):
    def test_changed_inputs_include_deleted_and_new_names(self):
        self.assertEqual(review.changed({'old/Cargo.lock': 'a', 'go.mod': 'b'},
                                        {'new/Cargo.lock': 'a', 'go.mod': 'b'}),
                         ['new/Cargo.lock', 'old/Cargo.lock'])

    def test_comparison_is_version_and_file_specific(self):
        baseline = review.findings(report('1', 'OSV-1'))
        self.assertFalse(review.findings(report('1', 'OSV-1')) - baseline)
        self.assertTrue(review.findings(report('2', 'OSV-1')) - baseline)
        self.assertFalse(review.findings(report('2')) - baseline)
        moved = report('1', 'OSV-1')
        moved['results'][0]['source']['path'] = 'other/Cargo.lock'
        self.assertTrue(review.findings(moved) - baseline)

    def test_missing_scanner_input_and_scanner_error_fail(self):
        def scanner(args, **kwargs):
            out = Path(args[args.index('--output-file') + 1])
            out.write_text(json.dumps({'results': []}))
            return subprocess.CompletedProcess(args, self.scanner_exit)
        for self.scanner_exit in (0, 127, 128):
            with self.subTest(exit=self.scanner_exit), tempfile.TemporaryDirectory() as tmp:
                with patch.object(subprocess, 'check_output', side_effect=[b'1', b'x']), \
                        patch.object(subprocess, 'run', side_effect=scanner):
                    with self.assertRaises(ValueError):
                        review.scan({'pubspec.lock': 'a' * 40}, Path(tmp), Path(tmp) / 'out.json', 'json')

    def test_matrix_covers_build_scripts_and_missing_history(self):
        self.assertEqual(languages(None), ALL)
        self.assertEqual(languages([b'.github/workflows/security-audit.yml']), ALL)
        self.assertEqual(languages([b'android/app/build.gradle.kts', b'core/Clash.Meta', b'helper/Cargo.lock']),
                         ['go', 'java-kotlin', 'rust'])
        self.assertEqual(languages([b'tool/release.mjs', b'.github/actions/android/action.yml']),
                         ['actions', 'javascript-typescript'])
        self.assertEqual(languages([b'docs/maintenance/architecture.md']), [])
