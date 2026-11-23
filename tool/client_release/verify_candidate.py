#!/usr/bin/env python3
"""Read-only acceptance of artifacts from one manual ZolNit build attempt."""
from dataclasses import dataclass
from html import escape
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

from assemble_release import (COMMIT, CORE, MAX_ASSET_BYTES, REPOSITORY, REPOSITORY_ID, TARGETS,
                              GitHub, ReleaseError, check_record, extract, parse_provenance,
                              read_pubspec, require, sha256_file, verify_sums)
from candidate_packages import inspect_android, inspect_desktop, inspect_ios, mobile_sdk, package_names

WORKFLOW = '.github/workflows/cloud-build.yml'
FRESH = 'Start a fresh workflow dispatch if artifacts are missing, duplicated or from different attempts.'


@dataclass(frozen=True)
class Candidate:
    sha: str
    ref: str
    run_id: int
    number: int
    attempt: int
    platform: str
    version: str
    build: int

    @property
    def workflow_ref(self):
        return f'{REPOSITORY}/{WORKFLOW}@{self.ref}'


def candidate_context(env, root):
    require(env.get('GITHUB_REPOSITORY') == REPOSITORY and env.get('GITHUB_REPOSITORY_ID') == REPOSITORY_ID,
            'candidate repository identity mismatch')
    require(env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'candidate must be a manual dispatch')
    ref = env.get('GITHUB_REF', '')
    namespace = {'branch': 'refs/heads/', 'tag': 'refs/tags/'}.get(env.get('GITHUB_REF_TYPE'))
    require(namespace and ref.startswith(namespace) and
            subprocess.run(['git', '-C', root, 'check-ref-format', ref]).returncode == 0, 'invalid dispatch ref')
    require(env.get('GITHUB_WORKFLOW_REF') == f'{REPOSITORY}/{WORKFLOW}@{ref}', 'not the direct Cloud build workflow')
    sha = env.get('GITHUB_SHA', '')
    require(COMMIT.fullmatch(sha) and env.get('GITHUB_WORKFLOW_SHA') == sha, 'workflow and dispatch SHA mismatch')
    ids = [env.get('GITHUB_' + key, '') for key in ('RUN_ID', 'RUN_NUMBER', 'RUN_ATTEMPT')]
    require(all(re.fullmatch(r'[1-9][0-9]{0,18}', value) for value in ids), 'invalid run ID, number or attempt')
    platform = env.get('CANDIDATE_PLATFORM')
    require(platform == 'all' or any(platform == p for p, _, _ in TARGETS), 'invalid platform selection')
    require(env.get('SELECT_RESULT') == 'success', 'candidate selection did not succeed')
    require(env.get('PROJECT_RESULT') == ('skipped' if platform == 'ios' else 'success'), 'selected project build did not succeed')
    require(env.get('IOS_RESULT') == ('success' if platform in ('all', 'ios') else 'skipped'), 'selected iOS build did not succeed')
    head = subprocess.check_output(['git', '-C', root, 'rev-parse', 'HEAD'], text=True).strip()
    core = subprocess.check_output(['git', '-C', root, 'ls-tree', 'HEAD', 'core/Clash.Meta'], text=True).strip()
    require(head == sha and core == f'160000 commit {CORE}\tcore/Clash.Meta', 'checkout SHA or Core gitlink mismatch')
    pubspec = root / 'pubspec.yaml'
    match = re.search(r'^version:[ \t]*(\d+\.\d+\.\d+)\+', pubspec.read_text(encoding='utf-8'), re.M)
    require(match, 'candidate package version/build missing')
    version, build = read_pubspec(pubspec, 'v' + match[1])
    return Candidate(sha, ref, *map(int, ids), platform, version, build)


def artifact_records(github, context, wanted):
    body = github.get(f'repos/{REPOSITORY}/actions/runs/{context.run_id}/artifacts?per_page=100')
    require(isinstance(body, dict), 'malformed artifact inventory')
    batch = body.get('artifacts')
    require(isinstance(batch, list) and body.get('total_count') == len(batch) and len(batch) <= len(TARGETS),
            'unexpected or incomplete candidate artifact inventory')
    records, ids = {}, set()
    for record in batch:
        require(isinstance(record, dict) and isinstance(record.get('workflow_run'), dict), 'malformed artifact record')
        name, artifact_id = record.get('name'), record.get('id')
        require(isinstance(name, str) and name in wanted, 'unexpected candidate artifact name')
        require(type(artifact_id) is int and 0 < artifact_id < 2**63, 'invalid artifact ID')
        require(name not in records and artifact_id not in ids, 'duplicate candidate artifact name or ID')
        size = record.get('size_in_bytes')
        require(type(size) is int and 0 < size <= MAX_ASSET_BYTES, f'{name}: artifact size out of bounds')
        require(str(record['workflow_run'].get('head_repository_id')) == REPOSITORY_ID,
                f'{name}: artifact head repository mismatch')
        check_record(record, context, name)
        records[name] = record
        ids.add(artifact_id)
    require(set(records) == set(wanted), f'missing candidate artifacts: {", ".join(sorted(set(wanted) - records.keys()))}')
    return records


def verify_provenance(text, context, platform, arch):
    fields, modules = parse_provenance(text)
    expected = dict(source_repository=REPOSITORY, source_commit=context.sha, event_sha=context.sha,
                    workflow_revision=context.sha, workflow_ref=context.workflow_ref, run_id=str(context.run_id),
                    run_attempt=str(context.attempt), build_profile='zolnit', package_version=f'{context.version}+{context.build}',
                    native_ui='true', client_bundle='true')
    require('official_release' not in fields, 'candidate marked official')
    if mobile_sdk is not None or 'owned_dns' in fields:
        require(mobile_sdk is not None and fields.get('owned_dns') == 'strict-v1', 'owned DNS SDK provenance mismatch')
    if platform == 'ios':
        expected.update(source_kind='project', workflow_repository=REPOSITORY, workflow_commit=context.sha,
                        routing_observation='false', target='iOS arm64 physical device; simulator unsupported',
                        signing='ad hoc unsigned IPA; requires provisioning for device installation')
        require(not fields.keys() & {'app_bundle_id', 'observer_bundle_id', 'app_group'}, 'observer iOS candidate')
    else:
        compiled = 'dev' if platform == 'android' else 'stable'
        expected.update(target=f'{platform}-{arch}', client_safe_preview='false', distribution_channel='direct',
                        client_build_env=compiled, client_defines=f'APP_ENV={compiled};ZOLNIT_DISTRIBUTION=direct',
                        distribution='development artifact; no production signing or notarization',
                        run=f'https://github.com/{REPOSITORY}/actions/runs/{context.run_id}')
        if platform == 'windows':
            expected.update(windows_release_ready='false', windows_signing_report='windows-signing-report.txt')
    for key, value in expected.items():
        require(fields.get(key) == value, f'{platform}-{arch}: provenance {key} mismatch')
    require([m for m in modules if m[2] == 'core/Clash.Meta'] == [(' ', CORE, 'core/Clash.Meta')],
            'Core provenance mismatch')
    require(all(m[0] == ' ' for m in modules), 'uninitialized or modified submodule')
    tools = {'Flutter ': '3.47.6', 'go version go': '1.27.1', 'rustc ': '1.99.0'}
    if platform in ('macos', 'ios'):
        tools['Xcode '] = '27.1'
        require(re.fullmatch(r'27(?:\.\d+){1,2}', fields.get('apple_sdk', '')), 'unexpected Apple SDK')
    for prefix, version in tools.items():
        require(re.findall(r'^' + re.escape(prefix) + r'(\S+)', text, re.M) == [version],
                f'{prefix.strip()} version mismatch')
    return fields


def inspect_artifact(context, github, record, work, platform, arch):
    name = record['name']
    packages = package_names(platform, arch, context.version)
    expected = {*packages, 'SHA256SUMS', 'source-provenance.txt'}
    if platform == 'windows':
        expected.add('windows-signing-report.txt')
    archive = work / 'download.zip'
    github.download(f'repos/{REPOSITORY}/actions/artifacts/{record["id"]}/zip', archive)
    require(archive.stat().st_size == record['size_in_bytes'], 'truncated artifact or API size mismatch')
    require(sha256_file(archive) == record['digest'][7:], 'GitHub artifact digest mismatch')
    with zipfile.ZipFile(archive) as zipped:
        members = zipped.infolist()
        require(len(members) <= 64, 'unexpected number of candidate artifact members')
        names = {m.filename for m in members}
        require(len(members) == len(names), 'duplicate artifact members')
        require(expected <= names, f'missing artifact members: {", ".join(sorted(expected - names))}')
        for member in members:
            require(member.filename in expected or re.fullmatch(r'(?:httpdns|owned-dns|sdk)[-.][\w.-]+\.(?:json|txt)', member.filename),
                    'unexpected product or evidence file')
            limit = MAX_ASSET_BYTES if member.filename in packages else 256 * 1024
            require(0 < member.file_size <= limit, 'empty or oversized artifact member')
    directory = work / 'contents'
    members = extract(archive, directory)
    archive.unlink()
    listed = verify_sums(directory, members)
    fields = verify_provenance((directory / 'source-provenance.txt').read_text(encoding='utf-8'), context, platform, arch)
    if platform == 'ios':
        inspect_ios(directory / packages[0], context.version, context.build, fields['apple_sdk'])
    elif platform == 'android':
        inspect_android(directory / packages[0], context.version, context.build)
    else:
        inspect_desktop(directory, listed, platform, arch, context.version, context.build)
    return {p: listed[p] for p in packages}


def verify(env, root, github, work, emit):
    context = candidate_context(env, root)
    wanted = {template.format(run=context.number): (platform, arch) for platform, arch, template in TARGETS
              if context.platform in ('all', platform)}
    emit(f'Run {context.run_id}, attempt {context.attempt} · `{context.sha}` · ZolNit {context.version}+{context.build}')
    records = artifact_records(github, context, wanted)
    emit('\n| Development target / file | Artifact ID | SHA-256 | Result |\n|---|---:|---|---|')
    for name, (platform, arch) in wanted.items():
        item = records[name]
        try:
            with tempfile.TemporaryDirectory(dir=work) as tmp:
                packages = inspect_artifact(context, github, item, Path(tmp), platform, arch)
        except Exception as error:
            emit(f'| {platform} {arch} | {item["id"]} | `{item["digest"][7:]}` | failed |')
            raise ReleaseError(f'{name}: {error}') from error
        emit(f'| {platform} {arch} | {item["id"]} | `{item["digest"][7:]}` | verified |')
        for package, digest in packages.items():
            emit(f'| ↳ `{package}` | | `{digest}` | verified |')


def main():
    with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a', encoding='utf-8') as summary:
        def emit(line):
            print(line, file=summary)
        emit('## Manual ZolNit candidate verification')
        try:
            verify(os.environ, Path.cwd(), GitHub(), os.environ['RUNNER_TEMP'], emit)
        except Exception as error:
            emit(f'\n**Failed** <code>{escape(ascii(str(error))[:500])}</code>\n\n{FRESH}')
            print('::error::Candidate verification failed. See the step summary.', file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
