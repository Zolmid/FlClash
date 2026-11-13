"""Bounded, non-secret checkpoints for macOS notary submissions."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from types import SimpleNamespace

import assemble_release as release

MANUAL_WORKFLOW = '.github/workflows/macos-notarization-verify.yml'
BRANCH = 'codex/native-client-shared'
RECEIPT = 'pending-receipt.json'
PAYLOADS = {'app': 'notary-app.zip', 'dmg': 'notary-dmg.dmg'}
UUID = re.compile(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')


class PendingError(Exception):
    pass


def safe_error(error):
    message = str(error)
    allowed = {
        'new app submission requires explicit approval',
        'retry has no checkpoint; reconcile with Apple before retrying',
        'submission outcome unknown; reconcile with Apple before retrying',
        'checkpoint source or signer mismatch', 'checkpoint payload checksum mismatch',
        'checkpoint source evidence missing', 'notarization rejected; checkpoint cannot be resubmitted',
        'duplicate submission blocked', 'notary status unavailable', 'checkpoint producer workflow rejected',
        'checkpoint repository mismatch', 'checkpoint artifact name mismatch',
        'previous DMG stage ran without a checkpoint; reconcile with Apple before retrying',
        'previous DMG stage history unavailable; reconcile with Apple before retrying',
    }
    return message if message in allowed else 'details withheld'


def require(condition, message):
    if not condition:
        raise PendingError(message)


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


class Checkpoint:
    def __init__(self, directory, binding, resume=None):
        self.directory = Path(directory)
        require(not self.directory.exists(), 'checkpoint output already exists')
        self.binding = binding
        self.data = None
        if resume is not None:
            source = Path(resume)
            require(source.is_dir() and not source.is_symlink(), 'invalid checkpoint directory')
            require((source / RECEIPT).is_file() and not (source / RECEIPT).is_symlink(), 'checkpoint receipt missing')
            data = json.loads((source / RECEIPT).read_text())
            require(isinstance(data, dict) and set(data) == {'schema_version', 'binding', 'stage', 'payloads',
                    'submission_id', 'state', 'app_notary_id'}, 'invalid checkpoint receipt')
            require(data['schema_version'] == 1 and data['binding'] == binding, 'checkpoint source or signer mismatch')
            require(data['stage'] in PAYLOADS, 'invalid checkpoint stage')
            require(data['state'] in ('submitting', 'pending', 'accepted', 'invalid'), 'invalid checkpoint state')
            names = {'notary-app.zip'} if data['stage'] == 'app' else set(PAYLOADS.values())
            require(isinstance(data['payloads'], dict) and set(data['payloads']) == names and
                    {p.name for p in source.iterdir()} == names | {RECEIPT}, 'unexpected checkpoint files')
            for name in names:
                path, item = source / name, data['payloads'][name]
                require(path.is_file() and not path.is_symlink() and isinstance(item, dict) and
                        set(item) == {'sha256', 'size'} and 0 < path.stat().st_size <= release.MAX_ASSET_BYTES and
                        item['size'] == path.stat().st_size and item['sha256'] == release.sha256_file(path),
                        'checkpoint payload checksum mismatch')
            submission_id = data['submission_id']
            require(isinstance(submission_id, str) and UUID.fullmatch(submission_id),
                    'submission outcome unknown; reconcile with Apple before retrying')
            require(data['stage'] != 'dmg' or isinstance(data['app_notary_id'], str) and
                    UUID.fullmatch(data['app_notary_id']), 'accepted app submission missing')
            require(data['stage'] != 'app' or data['app_notary_id'] is None, 'invalid app checkpoint')
            require(data['state'] != 'invalid', 'notarization rejected; checkpoint cannot be resubmitted')
            shutil.copytree(source, self.directory)
            self.data = data

    def save(self):
        temporary = self.directory / '.receipt.tmp'
        with temporary.open('w') as handle:
            json.dump(self.data, handle, sort_keys=True)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, self.directory / RECEIPT)

    def reserve(self, path, stage, app_id=None):
        require(stage in PAYLOADS, 'invalid checkpoint stage')
        require(self.data is None or self.data['stage'] == 'app' and self.data['state'] == 'accepted' and
                stage == 'dmg' and app_id == self.data['submission_id'], 'duplicate submission blocked')
        self.directory.mkdir(parents=True, exist_ok=True)
        name = PAYLOADS[stage]
        target = self.directory / name
        with Path(path).open('rb') as reader, (self.directory / '.payload.tmp').open('wb') as writer:
            shutil.copyfileobj(reader, writer)
            writer.flush()
            os.fsync(writer.fileno())
        os.replace(self.directory / '.payload.tmp', target)
        size, digest = target.stat().st_size, release.sha256_file(target)
        require(0 < size <= release.MAX_ASSET_BYTES and digest == release.sha256_file(path), 'invalid signed payload')
        payloads = {} if self.data is None else dict(self.data['payloads'])
        payloads[name] = {'sha256': digest, 'size': size}
        self.data = {'schema_version': 1, 'binding': self.binding, 'stage': stage, 'payloads': payloads,
                     'submission_id': None, 'state': 'submitting', 'app_notary_id': app_id}
        self.save()
        return target

    def submitted(self, submission_id):
        require(isinstance(submission_id, str) and UUID.fullmatch(submission_id),
                'submission outcome unknown; reconcile with Apple before retrying')
        self.data.update(submission_id=submission_id, state='pending')
        self.save()

    def status(self, status):
        require(status in ('Accepted', 'In Progress', 'Invalid', 'Rejected'), 'notary status unavailable')
        self.data['state'] = {'Accepted': 'accepted', 'In Progress': 'pending',
                              'Invalid': 'invalid', 'Rejected': 'invalid'}[status]
        self.save()


def download_checkpoint(github, artifact_id, context, arch, work):
    require(re.fullmatch(r'[1-9][0-9]*', str(artifact_id)), 'invalid checkpoint artifact ID')
    record = github.get(f'repos/{release.REPOSITORY}/actions/artifacts/{artifact_id}')
    require(str(record.get('id')) == str(artifact_id), 'checkpoint artifact ID mismatch')
    origin = record.get('workflow_run') or {}
    require(isinstance(origin.get('id'), int), 'checkpoint origin missing')
    run = github.get(f'repos/{release.REPOSITORY}/actions/runs/{origin["id"]}')
    repo, head = run.get('repository') or {}, run.get('head_repository') or {}
    require(run.get('id') == origin['id'] and str(repo.get('id')) == release.REPOSITORY_ID and
            repo.get('full_name') == release.REPOSITORY and str(head.get('id')) == release.REPOSITORY_ID and
            head.get('full_name') == release.REPOSITORY, 'checkpoint repository mismatch')
    manual = run.get('path') == MANUAL_WORKFLOW and run.get('event') == 'workflow_dispatch' and run.get('head_branch') == BRANCH
    formal = run.get('path') == release.WORKFLOW and run.get('event') == 'push' and run.get('head_sha') == context.sha and run.get('head_branch') == context.tag
    require(manual or formal, 'checkpoint producer workflow rejected')
    require(run.get('status') == 'completed' or str(origin['id']) == os.environ.get('GITHUB_RUN_ID'),
            'checkpoint producer is still running')
    name = record.get('name', '')
    match = re.fullmatch(rf'macos-notary-checkpoint-{arch}-{origin["id"]}-([1-9][0-9]*)-(app|dmg|final)', name)
    require(match and int(match[1]) <= run.get('run_attempt', 0), 'checkpoint artifact name mismatch')
    origin_context = SimpleNamespace(run_id=origin['id'], sha=run.get('head_sha'))
    directory, _, _ = release.fetch_artifact(github, record, origin_context, name, work)
    return directory


def source_evidence(directory, context, arch):
    receipt = Path(directory) / RECEIPT
    require(receipt.is_file() and not receipt.is_symlink(), 'checkpoint receipt missing')
    data = json.loads(receipt.read_text())
    binding = data.get('binding') if isinstance(data, dict) else None
    expected = {'source_repository': release.REPOSITORY, 'core_sha': release.CORE, 'source_commit': context.sha,
                'source_run_id': context.run_id, 'version': context.version, 'arch': arch,
                'input_archive': f'FlClash-macos-{arch}-release.zip'}
    require(isinstance(binding, dict) and all(binding.get(k) == v for k, v in expected.items()),
            'checkpoint source or signer mismatch')
    require(isinstance(binding.get('source_artifact_id'), int) and binding['source_artifact_id'] > 0,
            'checkpoint source evidence missing')
    for key in ('input_sha256', 'source_artifact_sha256', 'source_provenance_sha256'):
        require(isinstance(binding.get(key), str) and release.DIGEST.fullmatch(binding[key]),
                'checkpoint source evidence missing')
    return {key: binding[key] for key in ('source_artifact_id', 'source_artifact_sha256',
                                         'source_provenance_sha256', 'input_sha256')}


def previous_dmg_stage_ran(github, run_id, attempt, arch):
    unavailable = 'previous DMG stage history unavailable; reconcile with Apple before retrying'
    for previous in range(1, attempt):
        jobs, page, total = [], 1, None
        while total is None or len(jobs) < total:
            body = github.get(f'repos/{release.REPOSITORY}/actions/runs/{run_id}/attempts/{previous}/jobs?per_page=100&page={page}')
            batch, count = body.get('jobs'), body.get('total_count')
            require(isinstance(batch, list) and isinstance(count, int) and count > 0 and batch and
                    (total is None or total == count), unavailable)
            total = count
            jobs.extend(batch)
            require(len(jobs) <= total, unavailable)
            page += 1
        require(all(job.get('run_id') == int(run_id) and job.get('run_attempt') == previous for job in jobs), unavailable)
        stage_name = 'Verify and perform dmg stage'
        for job in jobs:
            name = job.get('name', '').split(' / ')[-1]
            if name.startswith('macOS dmg · ') and name not in ('macOS dmg · arm64', 'macOS dmg · x64'):
                require(job.get('status') == 'completed' and job.get('conclusion') == 'skipped' and
                        all(step.get('conclusion') == 'skipped' for step in job.get('steps', [])), unavailable)
                continue
            if any(step.get('name') == stage_name for step in job.get('steps', [])):
                require(name in ('macOS dmg · arm64', 'macOS dmg · x64'), unavailable)
        target = f'macOS dmg · {arch}'
        matches = [job for job in jobs if job.get('name', '').split(' / ')[-1] == target]
        require(len(matches) <= 1, unavailable)
        if not matches:
            continue
        job = matches[0]
        if job.get('status') == 'completed' and job.get('conclusion') == 'skipped':
            continue
        stages = [step for step in job.get('steps', []) if step.get('name') == stage_name]
        require(len(stages) == 1, unavailable)
        if stages[0].get('status') != 'completed' or stages[0].get('conclusion') != 'skipped':
            return True
    return False


def require_dmg_checkpoint(directory):
    data = json.loads((Path(directory) / RECEIPT).read_text())
    require(data.get('stage') == 'dmg',
            'previous DMG stage ran without a checkpoint; reconcile with Apple before retrying')
    submission = data.get('submission_id')
    require(isinstance(submission, str) and UUID.fullmatch(submission),
            'submission outcome unknown; reconcile with Apple before retrying')


def select_checkpoint(github, explicit, context, arch, work, env, mode='app'):
    if explicit and mode == 'final':
        return download_checkpoint(github, explicit, context, arch, work)
    attempt = env.get('GITHUB_RUN_ATTEMPT', '1')
    require(re.fullmatch(r'[1-9][0-9]*', attempt), 'invalid workflow attempt')
    if int(attempt) > 1:
        run_id = env.get('GITHUB_RUN_ID', '')
        require(re.fullmatch(r'[1-9][0-9]*', run_id), 'invalid workflow run')
        matches = []
        for record in github.artifacts(int(run_id)):
            match = re.fullmatch(rf'macos-notary-checkpoint-{arch}-{run_id}-([1-9][0-9]*)-(app|dmg|final)', record.get('name', ''))
            if match and int(match[1]) < int(attempt):
                matches.append(((int(match[1]), {'app': 1, 'dmg': 2, 'final': 3}[match[2]]), record['id']))
        if mode == 'dmg':
            matches = [(rank, artifact) for rank, artifact in matches if rank[1] >= 2]
            if not matches:
                require(not previous_dmg_stage_ran(github, run_id, int(attempt), arch),
                        'previous DMG stage ran without a checkpoint; reconcile with Apple before retrying')
                require(explicit, 'retry has no checkpoint; reconcile with Apple before retrying')
                return download_checkpoint(github, explicit, context, arch, work)
        require(matches, 'retry has no checkpoint; reconcile with Apple before retrying')
        latest = max(a for a, _ in matches)
        candidates = [i for a, i in matches if a == latest]
        require(len(candidates) == 1, 'ambiguous retry checkpoint')
        directory = download_checkpoint(github, candidates[0], context, arch, work)
        if mode == 'dmg':
            require_dmg_checkpoint(directory)
        return directory
    return download_checkpoint(github, explicit, context, arch, work) if explicit else None
