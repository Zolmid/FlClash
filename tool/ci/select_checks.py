#!/usr/bin/env python3
"""Choose conservative CI coverage from an exact local Git comparison."""
import json
import os
from pathlib import Path
import re
import subprocess

SHA = re.compile(r'[0-9a-f]{40}')
CHECKS = ('dart', 'plugins', 'go', 'android', 'rust', 'windows-helper-test')


def changed_paths(base, head):
    if not all(isinstance(s, str) and SHA.fullmatch(s) and int(s, 16) for s in (base, head)):
        return None
    try:
        for commit in (base, head):
            subprocess.run(['git', 'cat-file', '-e', commit + '^{commit}'], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        subprocess.run(['git', 'merge-base', '--is-ancestor', base, head], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        result = subprocess.run(['git', 'diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', base, head, '--'],
                                check=True, capture_output=True, timeout=30).stdout
        if not result or len(result) > 2_000_000 or not result.endswith(b'\0'):
            return None
        return result[:-1].split(b'\0')
    except (OSError, subprocess.SubprocessError):
        return None


def profile(event_name, ref, event, head):
    if event_name == 'pull_request':
        base = event.get('pull_request', {}).get('base', {}).get('sha')
    elif event_name == 'push' and ref.startswith('refs/heads/') and ref != 'refs/heads/main' and not event.get('deleted'):
        base = event.get('before')
    else:
        return 'full'
    paths = changed_paths(base, head)
    if not paths:
        return 'full'
    if all(p == b'README.md' or (p.startswith(b'docs/maintenance/') and p.endswith(b'.md')) for p in paths):
        return 'docs'
    if all(p.startswith(b'test/') and p.endswith(b'_test.dart') for p in paths):
        return 'dart'
    return 'full'


def select(event_name, ref, event, head, official):
    kind = profile(event_name, ref, event, head) if not official else 'full'
    private = event.get('repository', {}).get('private') is True
    eligible = event_name in ('pull_request', 'merge_group', 'workflow_dispatch') or not private or official
    desktop = (event_name in ('pull_request', 'merge_group', 'workflow_dispatch') or not private) and not (
        event_name == 'push' and ref.startswith('refs/tags/v'))
    result = {name: eligible and (kind == 'full' or (kind == 'dart' and name == 'dart')) for name in CHECKS}
    result['desktop'] = desktop and kind == 'full'
    return kind, result


def main():
    env = os.environ
    try:
        event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
        if not isinstance(event, dict):
            raise ValueError('event must be an object')
        kind, selected = select(env['GITHUB_EVENT_NAME'], env['GITHUB_REF'], event,
                                env.get('GITHUB_SHA', ''), env.get('OFFICIAL_INPUT') == 'true')
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        kind, selected = 'full', {name: True for name in (*CHECKS, 'desktop')}
    with Path(env['GITHUB_OUTPUT']).open('a') as output:
        output.write(f'profile={kind}\n')
        for name, enabled in selected.items():
            output.write(f'{name.replace("-", "_")}={str(enabled).lower()}\n')
    print('CI profile:', kind, selected)


if __name__ == '__main__':
    main()
