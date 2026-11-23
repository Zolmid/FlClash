"""Summarize CodeQL output and reject high-severity primary locations changed by a PR."""
from functools import lru_cache
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


def primary_location(location):
    physical = location.get('physicalLocation', {})
    uri = urlsplit(physical.get('artifactLocation', {}).get('uri', ''))
    if uri.netloc or uri.scheme not in ('', 'file'):
        raise ValueError('Unrecognized source location in a high-severity result')
    path = Path(unquote(uri.path))
    if path.is_absolute():
        path = path.relative_to(Path.cwd())
    if not uri.path or '..' in path.parts:
        raise ValueError('High-severity location is outside the checkout')
    region = physical.get('region', {})
    first = region.get('startLine')
    return str(path), first, region.get('endLine', first)


@lru_cache(maxsize=None)
def additions(base, head, path):
    patch = subprocess.check_output(['git', '-C', '.', 'diff', '--unified=0', '--no-ext-diff',
                                     '--no-textconv', '--no-renames', base, head, '--', ':(literal)' + path],
                                    timeout=30)
    matches = re.findall(rb'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', patch, re.M)
    return [(int(start), int(start) + int(count or b'1') - 1) for start, count in matches if count != b'0']


def review(files, base, head):
    total = high = 0
    blocking = set()
    if not files:
        raise ValueError('Expected at least one CodeQL SARIF report')
    for file in files:
        doc = json.loads(file.read_text(encoding='utf-8'))
        if doc.get('version') != '2.1.0' or not doc.get('runs'):
            raise ValueError('Invalid SARIF 2.1.0 report')
        for run in doc['runs']:
            tool = run['tool']
            if tool['driver']['name'] != 'CodeQL':
                raise ValueError('Unexpected SARIF producer')
            rules = {r['id']: float(r.get('properties', {}).get('security-severity', 0))
                     for group in [tool['driver'], *tool.get('extensions', [])] for r in group.get('rules', [])}
            for finding in run.get('results', []):
                total += 1
                rule = finding['ruleId']
                if rules[rule] < 7:
                    continue
                high += 1
                if not base:
                    continue
                if not finding.get('locations'):
                    raise ValueError('A high-severity result has no reviewable primary location')
                for location in finding['locations']:
                    path, first, last = primary_location(location)
                    ranges = additions(base, head, path)
                    if any(first is None or first <= end and last >= start for start, end in ranges):
                        blocking.add((rule, path, first))
    return total, high, blocking


if __name__ == '__main__':
    base = os.environ.get('BASE_SHA')
    head = os.environ['GITHUB_SHA']
    if base or os.environ.get('GITHUB_EVENT_NAME') == 'pull_request':
        if not base or not all(re.fullmatch(r'[0-9a-f]{40}', v) for v in (base, head)):
            raise SystemExit('Invalid source comparison')
        subprocess.run(['git', '-C', '.', 'merge-base', '--is-ancestor', base, head], check=True)
    counts = review(list(Path(sys.argv[1]).glob('*.sarif')), base, head)
    total, high, blocking = counts
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
        summary.write(f'CodeQL reported {total} findings, {high} with security severity ≥7.\n')
        if base:
            summary.write(f'High-severity primary locations on lines changed since `{base}`: **{len(blocking)}**.\n')
    print(f'CodeQL results: total={total}, high={high}, blocking changed locations={len(blocking)}')
    raise SystemExit(1 if blocking else 0)
