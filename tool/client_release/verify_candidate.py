#!/usr/bin/env python3
"""Read-only acceptance of artifacts from one manual ZolNit build attempt."""
import os
import plistlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile
from types import SimpleNamespace

from assemble_release import (CORE, REPOSITORY, REPOSITORY_ID, TARGETS, GitHub,
                              ReleaseError, check_ios, fetch_artifact, parse_provenance,
                              public_names, read_pubspec, require, verify_sums)


def verify(env, root, github, work, emit):
    require(env.get('GITHUB_REPOSITORY') == REPOSITORY and env.get('GITHUB_REPOSITORY_ID') == REPOSITORY_ID,
            'candidate repository identity mismatch')
    require(env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'candidate must be a manual dispatch')
    require(env.get('GITHUB_RUN_ATTEMPT') == '1',
            'rerun attempts can reuse earlier artifacts; start a new workflow dispatch for a clean candidate')
    sha = env.get('GITHUB_SHA', '')
    workflow_sha = env.get('GITHUB_WORKFLOW_SHA', '')
    require(re.fullmatch(r'[0-9a-f]{40}', sha) and re.fullmatch(r'[0-9a-f]{40}', workflow_sha), 'invalid source or workflow SHA')
    run_id, number = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_NUMBER', '')
    require(run_id.isdigit() and number.isdigit(), 'missing run identity')
    platform = env.get('CANDIDATE_PLATFORM')
    require(platform in ('all', 'android', 'linux', 'macos', 'windows', 'ios'), 'invalid platform selection')
    require(env.get('PROJECT_RESULT') == ('skipped' if platform == 'ios' else 'success'), 'selected project build did not succeed')
    require(env.get('IOS_RESULT') == ('success' if platform in ('all', 'ios') else 'skipped'), 'selected iOS build did not succeed')
    head = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    core = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD:core/Clash.Meta'], text=True).strip()
    require(head == sha and core == CORE, 'checkout source SHA or Core gitlink mismatch')
    version_text = (Path(root) / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'^version:[ \t]*(\d+\.\d+\.\d+)\+([1-9]\d*)[ \t]*$', version_text, re.M)
    require(match, 'candidate package version/build missing')
    version, build = read_pubspec(Path(root) / 'pubspec.yaml', 'v' + match.group(1))
    context = SimpleNamespace(run_id=int(run_id), sha=sha)
    wanted = {template.format(run=number): (plat, arch) for plat, arch, template in TARGETS
              if platform in ('all', plat)}
    records = {}
    for record in github.artifacts(int(run_id)):
        name = record.get('name')
        if name in wanted:
            require(name not in records, f'duplicate candidate artifact {name}')
            records[name] = record
    require(set(records) == set(wanted), f'missing or expired candidate artifacts: {sorted(set(wanted) - set(records))}; start a new dispatch')
    emit('| Target | Artifact ID | Archive SHA-256 | Result |\n|---|---:|---|---|')
    for name, (plat, arch) in wanted.items():
        record = records[name]
        directory, names, outer = fetch_artifact(github, record, context, name, work)
        listed = verify_sums(directory, names)
        require('source-provenance.txt' in listed, f'{name} missing provenance')
        fields, modules = parse_provenance((directory / 'source-provenance.txt').read_text(encoding='utf-8'))
        expected = {'source_repository': REPOSITORY, 'source_commit': sha, 'event_sha': sha,
                    'workflow_revision': workflow_sha, 'workflow_ref': env.get('GITHUB_WORKFLOW_REF'),
                    'run_id': run_id, 'run_attempt': '1', 'build_profile': 'zolnit',
                    'package_version': f'{version}+{build}', 'native_ui': 'true', 'client_bundle': 'true'}
        if plat == 'ios':
            expected.update(source_kind='project', workflow_repository=REPOSITORY, workflow_commit=sha,
                            signing='ad hoc unsigned IPA; requires provisioning for device installation')
            packages = [f'ZolNit-{version}-ios-arm64-unsigned.ipa']
        else:
            compiled = 'dev' if plat == 'android' else 'stable'
            expected.update(target=f'{plat}-{arch}', client_safe_preview='false', distribution_channel='direct',
                            client_build_env=compiled, client_defines=f'APP_ENV={compiled};ZOLNIT_DISTRIBUTION=direct',
                            distribution='development artifact; no production signing or notarization')
            packages = ['FlClash-android-arm64-development.apk'] if plat == 'android' else public_names(version, plat, arch)
        for key, value in expected.items():
            require(fields.get(key) == value, f'{name}: provenance {key} mismatch: {fields.get(key)!r}, expected {value!r}')
        require('official_release' not in fields, f'{name}: candidate marked official')
        core_entries = [entry for entry in modules if entry[2] == 'core/Clash.Meta']
        require(core_entries == [(' ', CORE, 'core/Clash.Meta')], f'{name}: Core provenance mismatch')
        require(all(entry[0] in ' -' for entry in modules), f'{name}: modified submodule')
        if plat == 'ios':
            check_ios(directory, listed, version)
            with zipfile.ZipFile(directory / packages[0]) as ipa:
                info_path = next(name for name in ipa.namelist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', name))
                info = plistlib.loads(ipa.read(info_path))
                require(info.get('CFBundleIdentifier') == 'com.zolmid.zolnit' and
                        info.get('CFBundleShortVersionString') == version and
                        info.get('CFBundleVersion') == str(build), f'{name}: iOS package identity/version mismatch')
        for package in packages:
            require(package in listed and (directory / package).stat().st_size > 0, f'{name}: missing or empty {package}')
        emit(f'| {plat} {arch} | {record["id"]} | `{outer}` | verified |')
        for package in packages:
            emit(f'| ↳ `{package}` | — | `{listed[package]}` | verified |')


def main():
    summary = Path(os.environ['GITHUB_STEP_SUMMARY'])
    def emit(line):
        with summary.open('a', encoding='utf-8') as out:
            out.write(line + '\n')
    emit('## Manual ZolNit candidate verification')
    try:
        with tempfile.TemporaryDirectory(prefix='candidate-', dir=os.environ.get('RUNNER_TEMP')) as tmp:
            verify(os.environ, Path.cwd(), GitHub(), Path(tmp), emit)
        emit('\nVerified artifact identity, provenance and hashes; this is development build evidence, not device or release acceptance.')
    except (ReleaseError, OSError, ValueError, zipfile.BadZipFile, EOFError, subprocess.CalledProcessError) as error:
        emit(f'\n**Failed:** {error}\n\nStart a new manual dispatch after correcting the failure; do not combine attempts.')
        print(f'::error::Candidate verification failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
