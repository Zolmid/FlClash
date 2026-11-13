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
import macos_pending as pending
from macos_pending import GitHub

BRANCH = 'refs/heads/codex/native-client-shared'
WORKFLOW = '.github/workflows/macos-notarization-verify.yml'



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


def verify_and_sign(github, run_id, tag, arch, output, *, pending_output=None, resume_artifact='',
                    start_new=False, mode='all', official=False):
    release.require(arch in ('arm64', 'x64'), 'unsupported architecture')
    release.require(not output.exists() and not output.is_symlink(), 'output already exists')
    with tempfile.TemporaryDirectory(prefix='zolnit-verify-', dir=output.parent) as tmp:
        scratch = Path(tmp)
        signing.phase('source-context')
        if official:
            context = release.Context(os.environ, '.')
            release.require(not run_id and not tag, 'formal signing uses the current run only')
            release.require(github.tag_commit(context.tag) == context.sha, 'formal tag moved')
            entitlements = Path('macos/Runner/Release.entitlements')
        else:
            context, entitlements = verified_context(github, run_id, tag, scratch)
        signing.phase('artifact-verification')
        resume = pending.select_checkpoint(github, resume_artifact, context, arch, scratch, os.environ, mode)
        pending.require(resume is not None or start_new and mode in ('all', 'app'),
                        'new app submission requires explicit approval')
        directory = None
        if resume is None:
            name = f'flclash-macos-{arch}-{context.run_number}'
            records = [item for item in github.artifacts(context.run_id) if item.get('name') == name]
            release.require(len(records) == 1, f'expected exactly one {name} artifact')
            directory, names, outer = release.fetch_artifact(github, records[0], context, name, scratch)
            listed = release.verify_sums(directory, names)
            release.require('source-provenance.txt' in listed, 'source provenance missing')
            release.check_provenance((directory / 'source-provenance.txt').read_text(encoding='utf-8'),
                                     context, 'macos', arch)
            evidence = {'source_artifact_id': records[0]['id'], 'source_artifact_sha256': outer,
                        'source_provenance_sha256': listed['source-provenance.txt'],
                        'input_sha256': listed.get(f'FlClash-macos-{arch}-release.zip')}
        else:
            evidence = pending.source_evidence(resume, context, arch)
        signed = scratch / 'signed'
        signing.prepare(directory, signed, context.version, arch, context=context, entitlements=entitlements,
                        pending_dir=pending_output, resume=resume, mode=mode, source_evidence=evidence)
        if mode in ('all', 'final'):
            os.rename(signed, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-run-id', default='')
    parser.add_argument('--source-tag', default='')
    parser.add_argument('--arch', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pending-output', type=Path, required=True)
    parser.add_argument('--resume-artifact-id', default='')
    parser.add_argument('--start-new', choices=('true', 'false'), default='false')
    parser.add_argument('--mode', choices=('app', 'dmg', 'final'), default='app')
    parser.add_argument('--official', choices=('true', 'false'), default='false')
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(signum, _frame):
        raise signing.SigningError(f'verification interrupted by signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    try:
        signing.phase('dispatch')
        official = args.official == 'true'
        if official:
            release.Context(os.environ, '.')
            release.require(os.environ.get('MACOS_SIGNING_REQUIRED') == 'true', 'formal signing disabled')
        else:
            check_dispatch(os.environ)
        signing.phase('credentials')
        signing.check_secret_presence(os.environ)
        verify_and_sign(GitHub(), args.source_run_id, args.source_tag, args.arch, args.output,
                        pending_output=args.pending_output, resume_artifact=args.resume_artifact_id,
                        start_new=args.start_new == 'true', mode=args.mode, official=official)
    except Exception as error:
        code = 'pending' if isinstance(error, pending.PendingError) else ('signing' if isinstance(error, signing.SigningError) else ('source' if isinstance(error, release.ReleaseError) else 'unexpected'))
        detail = pending.safe_error(error) if code == 'pending' else (signing.safe_signing_error(error) if code == 'signing' else 'details withheld')
        print(f'::error::macos-verification phase={signing.current_phase} code={code}: {detail}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
