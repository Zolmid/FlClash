"""Validation and lease-bound orchestration for one device signing job."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import stat
import time
import zipfile

from apple_distribution import TEAM_ID, TARGET_BUNDLE_IDS
from device_provisioning import OPAQUE_RE, UDID_RE, ProvisioningError

TAG_RE = re.compile(r'^v(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})$')
SHA_RE = re.compile(r'^[a-f0-9]{64}$')
SOURCE_RE = re.compile(r'^[a-f0-9]{40}$')
LEASE_RE = re.compile(r'^[A-Za-z0-9_-]{43}$')


def validate_job(job: dict, now: int | None = None) -> dict:
    timestamp = int(time.time()) if now is None else now
    if not isinstance(job, dict) or job.get('team_id') != TEAM_ID or job.get('bundle_id') != TARGET_BUNDLE_IDS['app']:
        raise ProvisioningError('job_identity_invalid')
    if not isinstance(job.get('job_id'), str) or not OPAQUE_RE.fullmatch(job['job_id']) or not isinstance(job.get('lease_token'), str) or not LEASE_RE.fullmatch(job['lease_token']):
        raise ProvisioningError('job_lease_invalid')
    deadline = job.get('lease_expires_at')
    if type(deadline) is not int or deadline <= timestamp + 30 or deadline > timestamp + 600:
        raise ProvisioningError('job_lease_window_invalid')
    device, release = job.get('device'), job.get('release')
    if not isinstance(device, dict) or not isinstance(release, dict):
        raise ProvisioningError('job_payload_invalid')
    if not OPAQUE_RE.fullmatch(str(device.get('device_id', ''))) or not UDID_RE.fullmatch(str(device.get('udid', ''))):
        raise ProvisioningError('job_device_invalid')
    tag = release.get('tag', '')
    if not isinstance(tag, str) or not TAG_RE.fullmatch(tag) or not SOURCE_RE.fullmatch(str(release.get('source_sha', ''))) or not SHA_RE.fullmatch(str(release.get('archive_sha256', ''))):
        raise ProvisioningError('job_release_invalid')
    if type(release.get('build')) is not int or release['build'] <= 0 or type(release.get('archive_size')) is not int or not 1024 <= release['archive_size'] <= 1073741824:
        raise ProvisioningError('job_release_size_invalid')
    archive = release.get('archive_key', '')
    if not isinstance(archive, str) or not re.fullmatch(r'apple-adhoc/archives/[A-Za-z0-9._/-]{1,160}', archive) or any(p in ['', '.', '..'] for p in archive.split('/')):
        raise ProvisioningError('job_archive_key_invalid')
    expected = 'apple-adhoc/signed/' + tag + '/' + job['job_id'] + '.ipa'
    if job.get('expected_artifact_key') != expected or device['udid'] in expected or device['udid'] in archive:
        raise ProvisioningError('job_artifact_key_invalid')
    extensions = job.get('extensions')
    if not isinstance(extensions, list) or len(extensions) != 2 or any(not isinstance(x, str) for x in extensions) or set(extensions) != {TARGET_BUNDLE_IDS['necore'], TARGET_BUNDLE_IDS['widget']}:
        raise ProvisioningError('job_extensions_invalid')
    return job


def file_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def extract_verified_archive(path: Path, directory: Path, release: dict) -> Path:
    if path.is_symlink() or not path.is_file() or path.stat().st_size != release['archive_size'] or file_digest(path) != release['archive_sha256']:
        raise ProvisioningError('archive_digest_mismatch')
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if directory.is_symlink() or directory.stat().st_mode & 0o077 or any(directory.iterdir()):
        raise ProvisioningError('archive_directory_not_private_or_empty')
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        if not 1 <= len(members) <= 8192:
            raise ProvisioningError('archive_entry_limit')
        roots, seen, total = set(), set(), 0
        for member in members:
            parts = member.filename.rstrip('/').split('/')
            if not parts or any(p in ['', '.', '..'] for p in parts) or '\\' in member.filename or not parts[0].endswith('.xcarchive') or member.filename in seen:
                raise ProvisioningError('archive_path_invalid')
            roots.add(parts[0]); seen.add(member.filename)
            mode = (member.external_attr >> 16) & 0xffff
            if stat.S_IFMT(mode) not in [0, stat.S_IFREG, stat.S_IFDIR] or member.flag_bits & 1:
                raise ProvisioningError('archive_entry_type_invalid')
            if member.file_size < 0 or member.file_size > 512 * 1024 * 1024:
                raise ProvisioningError('archive_member_size_invalid')
            total += member.file_size
            if total > 2 * 1024 * 1024 * 1024:
                raise ProvisioningError('archive_total_size_invalid')
        if len(roots) != 1:
            raise ProvisioningError('archive_root_ambiguous')
        for member in members:
            target = directory / member.filename
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True, mode=0o700)
                continue
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            executable = ((member.external_attr >> 16) & 0o111) != 0
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o700 if executable else 0o600)
            written = 0
            with archive.open(member) as source, os.fdopen(fd, 'wb') as output:
                while True:
                    block = source.read(1024 * 1024)
                    if not block:
                        break
                    written += len(block)
                    if written > member.file_size:
                        raise ProvisioningError('archive_expansion_invalid')
                    output.write(block)
            if written != member.file_size:
                raise ProvisioningError('archive_truncated')
    return directory / roots.pop()


def process_job(job, archive_path, directory, provision, export, upload, complete, now=time.time):
    validate_job(job, int(now()))
    release = job['release']
    archive = extract_verified_archive(archive_path, directory / 'archive', release)
    credentials = provision(job, directory / 'profiles')
    if int(now()) >= job['lease_expires_at'] - 15:
        raise ProvisioningError('job_lease_expired_before_export')
    artifact = export(job, archive, credentials, directory / 'export')
    if artifact.is_symlink() or not artifact.is_file() or not 1024 <= artifact.stat().st_size <= 1073741824:
        raise ProvisioningError('exported_artifact_invalid')
    if int(now()) >= job['lease_expires_at'] - 15:
        raise ProvisioningError('job_lease_expired_before_upload')
    digest, size = file_digest(artifact), artifact.stat().st_size
    stored = upload(job, artifact, digest, size)
    if stored.get('artifact_key') != job['expected_artifact_key'] or stored.get('sha256') != digest or stored.get('size') != size:
        raise ProvisioningError('stored_artifact_attestation_mismatch')
    expires = min(int(now()) + 7 * 86400, int(credentials['expires_at']))
    if expires <= int(now()) + 60 or int(now()) >= job['lease_expires_at']:
        raise ProvisioningError('artifact_or_lease_expired')
    payload = {'job_id': job['job_id'], 'lease_token': job['lease_token'], 'outcome': 'ready',
               'team_id': TEAM_ID, 'bundle_id': TARGET_BUNDLE_IDS['app'], 'release_tag': release['tag'],
               'source_sha': release['source_sha'], 'archive_sha256': release['archive_sha256'],
               'artifact_key': job['expected_artifact_key'], 'artifact_sha256': digest,
               'artifact_size': size, 'artifact_expires_at': expires,
               'apple_device_resource_id': credentials['apple_device_resource_id']}
    return complete(payload)
