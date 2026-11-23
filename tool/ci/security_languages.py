"""Select CodeQL extractors supported by the pinned product toolchains."""
import json
import os
from pathlib import Path

from select_checks import changed_paths


EXTENSIONS = {
    'c-cpp': {'.c', '.cc', '.cpp', '.h', '.hpp', '.cxx', '.mm'},
    'go': {'.go'},
    'java-kotlin': {'.java', '.kt', '.kts', '.gradle'},
    'javascript-typescript': {'.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx'},
    'python': {'.py'},
    'ruby': {'.rb', '.erb', '.gemspec'},
    'rust': {'.rs'},
}
ALL = sorted({'actions', *EXTENSIONS})


def languages(paths):
    if paths is None:
        return ALL
    selected = set()
    for raw in paths:
        path = Path(os.fsdecode(raw))
        if str(path) in ('.github/workflows/security-audit.yml', '.github/workflows/source-analysis.yml',
                         'tool/ci/security_languages.py', 'tool/ci/review_sarif.py', 'tool/ci/review_base.py',
                         'tool/ci/select_checks.py') or str(path).startswith('.github/codeql/'):
            return ALL
        if str(path).startswith('.github/workflows/') or path.name in ('action.yml', 'action.yaml'):
            selected.add('actions')
        for language, suffixes in EXTENSIONS.items():
            if path.suffix.lower() in suffixes:
                selected.add(language)
        if path.name in ('go.mod', 'go.sum') or str(path) == 'core/Clash.Meta':
            selected.add('go')
        if path.name in ('Cargo.lock', 'Cargo.toml'):
            selected.add('rust')
        if str(path) == 'tool/ci/android_unit.sh' or str(path).startswith('.github/actions/android-check-setup/'):
            selected.add('java-kotlin')
    return sorted(selected)


if __name__ == '__main__':
    paths = None
    if os.environ.get('GITHUB_EVENT_NAME') == 'pull_request':
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
        paths = changed_paths(event['pull_request']['base']['sha'], os.environ['GITHUB_SHA'])
    selected = languages(paths)
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        output.write('languages=' + json.dumps(selected) + '\n')
        output.write('enabled=' + str(bool(selected)).lower() + '\n')
