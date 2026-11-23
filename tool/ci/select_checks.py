#!/usr/bin/env python3
"""Select cheaper checks only for reviewed ZolNit paths; other repositories keep their original matrix."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

SHA = re.compile(r'[0-9a-f]{40}')
CHECKS = ('dart', 'plugins', 'go', 'android', 'rust', 'windows-helper-test')
ANDROID_UNIT = re.compile(rb'android/tests/(?:app|common|service)/[A-Za-z0-9_]+Test\.kt')
MAX_PATHS = 500
MAX_DIFF_BYTES = 1_000_000


def git(*args, stdout=subprocess.PIPE):
    return subprocess.run(['git', '-C', '.', *args], check=True, stdin=subprocess.DEVNULL,
                          stdout=stdout, stderr=subprocess.DEVNULL, timeout=30).stdout


def valid_sha(value):
    return isinstance(value, str) and SHA.fullmatch(value) is not None and value != '0' * 40


def raw_paths(data):
    if not data or len(data) > MAX_DIFF_BYTES or not data.endswith(b'\0'):
        return None
    fields = data[:-1].split(b'\0')
    if len(fields) % 2 or len(fields) > MAX_PATHS * 2:
        return None
    paths = []
    for header, path in zip(fields[::2], fields[1::2]):
        meta = header.split(b' ')
        if (len(meta) != 5 or meta[0] not in (b':100644', b':000000') or meta[1] not in (b'100644', b'000000')
                or meta[4] not in (b'A', b'D', b'M') or not path):
            return None
        paths.append(path)
    return paths


def changed_paths(base, head, pr_head=None):
    if not valid_sha(base) or not valid_sha(head):
        return None
    try:
        if git('rev-parse', '--is-shallow-repository').strip() != b'false':
            return None
        git('merge-base', '--is-ancestor', base, head)
        if pr_head is not None:
            if not valid_sha(pr_head) or git('rev-list', '--parents', '-1', head).decode().split() != [head, base, pr_head]:
                return None
        with tempfile.TemporaryFile() as diff:
            git('diff', '--raw', '-z', '--no-renames', '--no-ext-diff', '--ignore-submodules=none',
                base, head, '--', stdout=diff)
            diff.seek(0)
            return raw_paths(diff.read(MAX_DIFF_BYTES + 1))
    except (OSError, UnicodeError, subprocess.SubprocessError):
        return None


def profile(event_name, ref, event, head):
    repo = event['repository']
    if repo.get('full_name') != 'Zolmid/FlClash' or repo.get('id') != 1420254999:
        return 'full'
    main = ref == 'refs/heads/main'
    if event_name == 'pull_request' and ref == f"refs/pull/{event.get('number')}/merge":
        pr = event['pull_request']
        if pr['base']['repo'].get('id') != repo['id'] or not valid_sha(pr['head'].get('sha')):
            return 'full'
        paths = changed_paths(pr['base']['sha'], head, pr['head']['sha'])
    elif (event_name == 'push' and ref.startswith('refs/heads/') and event.get('ref') == ref
          and ref != 'refs/heads/codex/native-client-shared' and event.get('after') == head
          and all(event.get(key) is False for key in ('created', 'deleted', 'forced'))):
        paths = changed_paths(event.get('before'), head)
    else:
        return 'full'
    if not paths:
        return 'full'
    product = [p for p in paths if not (p == b'README.md' or (p.startswith(b'docs/maintenance/') and p.endswith(b'.md')))]
    if not product:
        return 'docs'
    if not main and all(ANDROID_UNIT.fullmatch(p) for p in product):
        return 'android-tests'
    return 'full'


def select(event_name, ref, event, head, official, called=False):
    kind = 'full' if official or called else profile(event_name, ref, event, head)
    private = event['repository']['private']
    if type(private) is not bool:
        raise ValueError('missing repository visibility')
    ordinary = event_name in ('pull_request', 'merge_group', 'workflow_dispatch') or not private
    result = {name: (ordinary or official) and (kind == 'full' or (kind == 'android-tests' and name == 'android'))
              for name in CHECKS}
    result['desktop'] = ordinary and kind == 'full' and not (event_name == 'push' and ref.startswith('refs/tags/v'))
    return kind, result


def main():
    env = os.environ
    event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
    kind, selected = select(env['GITHUB_EVENT_NAME'], env['GITHUB_REF'], event, env.get('GITHUB_SHA'),
                            env.get('OFFICIAL_INPUT') == 'true', called=env.get('OFFICIAL_INPUT') != 'null')
    with Path(env['GITHUB_OUTPUT']).open('a') as output:
        output.write(f'profile={kind}\n')
        for name, enabled in selected.items():
            output.write(f'{name.replace("-", "_")}={str(enabled).lower()}\n')
    print('CI profile:', kind, selected)


if __name__ == '__main__':
    main()
