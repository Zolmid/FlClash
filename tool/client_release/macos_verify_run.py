#!/usr/bin/env python3
"""Verify a previous formal run and notarize its macOS artifact without publishing."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
from types import SimpleNamespace

import assemble_release as release
import macos_notarize as signing

BRANCH = 'refs/heads/codex/native-client-shared'
WORKFLOW = '.github/workflows/macos-notarization-verify.yml'


class GitHub(release.GitHub):
    def get(self, path):
        try:
            result = subprocess.run(['gh', 'api', '-H', 'Accept: application/vnd.github+json', path],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            return json.loads(result.stdout)
        except (subprocess.CalledProcessError, ValueError) as error:
            raise release.ReleaseError('GitHub API request failed or returned invalid JSON') from error

    def download(self, path, destination):
        try:
            with open(destination, 'xb') as handle:
                subprocess.run(['gh', 'api', path], check=True, stdout=handle, stderr=subprocess.PIPE)
        except subprocess.CalledProcessError as error:
            raise release.ReleaseError('GitHub artifact download failed') from error


def check_dispatch(env):
    release.require(env.get('GITHUB_EVENT_NAME') == 'workflow_dispatch', 'verification requires manual dispatch')
    release.require(env.get('GITHUB_REPOSITORY') == release.REPOSITORY and
                    env.get('GITHUB_REPOSITORY_ID') == release.REPOSITORY_ID, 'wrong dispatch repository')
    release.require(env.get('GITHUB_REF') == BRANCH, 'verification requires the approved branch')
    release.require(env.get('GITHUB_WORKFLOW_REF') == f'{release.REPOSITORY}/{WORKFLOW}@{BRANCH}',
                    'wrong dispatch workflow')
    release.require(env.get('MACOS_NOTARIZATION_VERIFY_ENABLED') == 'true', 'manual verification is disabled')


def source_file(github, sha, path):
    payload = github.get(f'repos/{release.REPOSITORY}/contents/{path}?ref={sha}')
    release.require(payload.get('type') == 'file' and payload.get('encoding') == 'base64',
                    f'could not verify source file {path}')
    try:
        content = base64.b64decode(''.join(payload.get('content', '').split()), validate=True)
    except (TypeError, ValueError) as error:
        raise release.ReleaseError(f'invalid source file encoding for {path}') from error
    blob_sha = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
    release.require(payload.get('sha') == blob_sha and payload.get('size') == len(content),
                    f'source file digest mismatch for {path}')
    return content


def verified_context(github, run_id, tag, scratch):
    release.require(re.fullmatch(r'[1-9][0-9]{0,19}', run_id) is not None, 'invalid source run ID')
    release.require(release.TAG.fullmatch(tag) is not None, 'invalid source tag')
    run = github.get(f'repos/{release.REPOSITORY}/actions/runs/{run_id}')
    repo, head_repo = run.get('repository') or {}, run.get('head_repository') or {}
    release.require(run.get('id') == int(run_id) and str(repo.get('id')) == release.REPOSITORY_ID and
                    repo.get('full_name') == release.REPOSITORY and
                    str(head_repo.get('id')) == release.REPOSITORY_ID and
                    head_repo.get('full_name') == release.REPOSITORY, 'source run repository mismatch')
    release.require(run.get('event') == 'push' and run.get('path') == release.WORKFLOW and
                    run.get('status') == 'completed' and run.get('conclusion') == 'success',
                    'source run is not a successful formal release push')
    sha = run.get('head_sha') or ''
    release.require(release.COMMIT.fullmatch(sha) is not None, 'source run has invalid commit')
    release.require(github.tag_commit(tag) == sha, 'source tag and source run commit differ')
    number = run.get('run_number')
    release.require(isinstance(number, int) and not isinstance(number, bool) and number > 0,
                    'source run has invalid run number')
    pubspec = scratch / 'pubspec.yaml'
    pubspec.write_bytes(source_file(github, sha, 'pubspec.yaml'))
    version, build = release.read_pubspec(pubspec, tag)
    entitlements = scratch / 'Release.entitlements'
    entitlements.write_bytes(source_file(github, sha, 'macos/Runner/Release.entitlements'))
    context = SimpleNamespace(sha=sha, tag=tag, version=version, build=build, run_id=int(run_id),
                              run_number=number,
                              run_url=f'https://github.com/{release.REPOSITORY}/actions/runs/{run_id}')
    return context, entitlements


def verify_and_sign(github, run_id, tag, arch, output):
    release.require(arch in ('arm64', 'x64'), 'unsupported architecture')
    release.require(not output.exists() and not output.is_symlink(), 'output already exists')
    with tempfile.TemporaryDirectory(prefix='zolnit-verify-', dir=output.parent) as tmp:
        scratch = Path(tmp)
        context, entitlements = verified_context(github, run_id, tag, scratch)
        name = f'flclash-macos-{arch}-{context.run_number}'
        records = [item for item in github.artifacts(context.run_id) if item.get('name') == name]
        release.require(len(records) == 1, f'expected exactly one {name} artifact')
        directory, names, _ = release.fetch_artifact(github, records[0], context, name, scratch)
        listed = release.verify_sums(directory, names)
        release.require('source-provenance.txt' in listed, 'source provenance missing')
        release.check_provenance((directory / 'source-provenance.txt').read_text(encoding='utf-8'),
                                 context, 'macos', arch)
        signed = scratch / 'signed'
        signing.prepare(directory, signed, context.version, arch, context=context, entitlements=entitlements)
        os.rename(signed, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-run-id', required=True)
    parser.add_argument('--source-tag', required=True)
    parser.add_argument('--arch', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(signum, _frame):
        raise signing.SigningError(f'verification interrupted by signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    try:
        check_dispatch(os.environ)
        verify_and_sign(GitHub(), args.source_run_id, args.source_tag, args.arch, args.output)
    except Exception as error:
        print(f'::error::Verification failed: {type(error).__name__}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
