"""Choose the exact comparison used for pull-request and stable-tag findings."""
import json
import os
from pathlib import Path
import re
import subprocess


STABLE = re.compile(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')


def comparison_base(env):
    if env.get('GITHUB_EVENT_NAME') == 'pull_request':
        event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
        base = event['pull_request']['base']['sha']
        if not re.fullmatch('[0-9a-f]{40}', base):
            raise ValueError('Invalid PR base SHA')
        return base
    tag = env.get('GITHUB_REF_NAME', '')
    current = STABLE.fullmatch(tag)
    if env.get('GITHUB_REF_TYPE') != 'tag' or not current:
        return ''
    if env.get('GITHUB_WORKFLOW_REF') != f"{env['GITHUB_REPOSITORY']}/.github/workflows/client-release.yml@refs/tags/{tag}":
        return ''
    if subprocess.check_output(['git', '-C', '.', 'rev-parse', '--is-shallow-repository'], text=True).strip() != 'false':
        raise ValueError('Full history is required to choose the preceding stable tag')
    tags = subprocess.check_output(['git', '-C', '.', 'tag', '--merged', env['GITHUB_SHA']], text=True).splitlines()
    earlier = [(tuple(map(int, m.groups())), t) for t in tags if (m := STABLE.fullmatch(t))]
    earlier = [entry for entry in earlier if entry[0] < tuple(map(int, current.groups()))]
    if not earlier:
        raise ValueError('No lower stable tag is reachable; establish the release baseline before tagging')
    previous = max(earlier)[1]
    return subprocess.check_output(['git', '-C', '.', 'rev-parse', f'refs/tags/{previous}^{{commit}}'], text=True).strip()


if __name__ == '__main__':
    print('base=' + comparison_base(os.environ))
