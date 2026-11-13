"""Bounded private transport for the separately approved Apple signing runner."""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import time
import urllib.error
import urllib.request

from device_job import validate_job, file_digest
from device_provisioning import RESOURCE_RE, ProvisioningError

ORIGIN = 'https://link.zolmid.com'
API = '/api/v1/zolnit/client/apple/signer'
EDGE = '/__release/v1/apple'
PART_BYTES = 8 * 1024 * 1024
MAX_BYTES = 1024 * 1024 * 1024
TAG = re.compile(r'v(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})\.(0|[1-9][0-9]{0,9})')
SHA = re.compile(r'[a-f0-9]{64}')
SESSION = re.compile(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}')
EXTENSIONS = ['com.zolmid.zolnit.NECore', 'com.zolmid.zolnit.Widget']
SIGNED_TTL = 604800


class TransportError(ProvisioningError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise TransportError('signing_redirect_rejected')


def proof(secret: str, message: str) -> str:
    return base64.urlsafe_b64encode(hmac.new(secret.encode(), message.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()


def expected_archive_key(tag: str) -> str:
    if not isinstance(tag, str) or not TAG.fullmatch(tag):
        raise TransportError('release_identity_invalid')
    return 'apple-adhoc/archives/' + tag + '/ZolNit-' + tag[1:] + '-ios-arm64.xcarchive.zip'


class SigningTransport:
    def __init__(self, token_factory, opener=None, now=time.time):
        self.token_factory = token_factory
        self.opener = opener or urllib.request.build_opener(NoRedirect())
        self.now = now

    def _open(self, path, method='GET', body=None, headers=None):
        if not isinstance(path, str) or not path.startswith((API + '/', EDGE + '/')) or any(c in path for c in ['?', '#', '%', '\\', '\r', '\n']) or '//' in path or '..' in path:
            raise TransportError('signing_path_rejected')
        token = self.token_factory()
        if not isinstance(token, str) or not 1 <= len(token) <= 16384 or any(c in token for c in ['\r', '\n', '\0']):
            raise TransportError('signing_identity_invalid')
        request_headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/json', 'User-Agent': 'ZolNit-Apple-Signer/1'}
        request_headers.update(headers or {})
        request = urllib.request.Request(ORIGIN + path, data=body, method=method, headers=request_headers)
        try:
            response = self.opener.open(request, timeout=45)
            if response.geturl() != ORIGIN + path:
                response.close()
                raise TransportError('signing_redirect_rejected')
            return response
        except urllib.error.HTTPError as error:
            raise TransportError('signing_http_' + str(error.code)) from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise TransportError('signing_transport_unavailable') from None

    def _json(self, path, body, method='POST', headers=None, binary=False):
        payload = body if binary else json.dumps(body, separators=(',', ':')).encode()
        request_headers = {'Content-Type': 'application/octet-stream' if binary else 'application/json'}
        request_headers.update(headers or {})
        return self._parse(self._open(path, method, payload, request_headers))

    def _parse(self, response):
        with response:
            if response.status == 204:
                return {}
            if response.status != 200 or not response.headers.get('Content-Type', '').lower().startswith('application/json'):
                raise TransportError('signing_response_invalid')
            raw = response.read(65537)
        if len(raw) > 65536:
            raise TransportError('signing_response_too_large')
        try:
            result = json.loads(raw)
        except (ValueError, UnicodeError):
            raise TransportError('signing_response_invalid') from None
        if not isinstance(result, dict):
            raise TransportError('signing_response_invalid')
        return result

    def authorize_archive(self, tag, source_sha, build):
        if not isinstance(tag, str) or not TAG.fullmatch(tag) or not isinstance(source_sha, str) or not re.fullmatch(r'[a-f0-9]{40}', source_sha) or type(build) is not int or not 1 <= build <= 2147483647:
            raise TransportError('release_identity_invalid')
        data = self._json(API + '/authorize', {'schema_version': 1, 'tag': tag, 'source_sha': source_sha, 'build': build}).get('data')
        if not isinstance(data, dict) or not re.fullmatch(r'[A-Za-z0-9_-]{43}', str(data.get('lease', ''))) or type(data.get('expires_at')) is not int or data['expires_at'] <= self.now() + 60:
            raise TransportError('origin_authorization_invalid')
        return data['lease']

    def claim_job(self):
        data = self._json(API + '/claim', {}).get('data')
        if not isinstance(data, dict) or 'job' not in data:
            raise TransportError('signing_job_response_invalid')
        job = data['job']
        return validate_job(job, int(self.now())) if job is not None else None

    def renew_job(self, job):
        data = self._json(API + '/renew', {k: job[k] for k in ['job_id', 'lease_token']}).get('data')
        if not isinstance(data, dict) or data.get('job_id') != job['job_id'] or data.get('status') != 'leased' or type(data.get('lease_expires_at')) is not int or not self.now() + 30 < data['lease_expires_at'] <= self.now() + 600:
            raise TransportError('signing_lease_response_invalid')
        return data

    def complete_job(self, payload):
        data = self._json(API + '/complete', payload).get('data')
        if not isinstance(data, dict) or data.get('job_id') != payload.get('job_id') or data.get('status') not in ['ready', 'queued', 'failed', 'cancelled', 'superseded']:
            raise TransportError('signing_completion_invalid')
        return data

    def register_archive(self, tag, source_sha, build, stored):
        payload = {'schema_version': 1, 'tag': tag, 'source_sha': source_sha, 'build': build,
                   'archive_key': stored.get('archive_key'), 'archive_sha256': stored.get('archive_sha256'),
                   'archive_size': stored.get('archive_size'), 'extensions': list(EXTENSIONS)}
        if (payload['archive_key'] != expected_archive_key(tag) or not re.fullmatch(r'[a-f0-9]{40}', str(source_sha))
                or type(build) is not int or not 1 <= build <= 2147483647 or not SHA.fullmatch(str(payload['archive_sha256']))
                or type(payload['archive_size']) is not int or not 1024 <= payload['archive_size'] <= MAX_BYTES):
            raise TransportError('archive_registration_invalid')
        data = self._json(API + '/archive-ready', payload).get('data')
        if not isinstance(data, dict) or data.get('state') != 'ready' or any(data.get(k) != v for k, v in payload.items() if k != 'schema_version'):
            raise TransportError('archive_registration_mismatch')
        return data

    def archive_status(self, tag, source_sha, build):
        """Metadata of the ready archive for this exact source, None only on 404; every other answer fails closed."""
        if (not isinstance(tag, str) or not TAG.fullmatch(tag) or not isinstance(source_sha, str)
                or not re.fullmatch(r'[a-f0-9]{40}', source_sha) or type(build) is not int or not 1 <= build <= 2147483647):
            raise TransportError('release_identity_invalid')
        try:
            response = self._open(EDGE + '/archives/' + tag, 'HEAD')
        except TransportError as error:
            if str(error) == 'signing_http_404':
                return None
            raise
        with response:
            headers = response.headers
            length = headers.get('Content-Length') or ''
            digest = headers.get('X-Archive-Sha256') or ''
            if (response.status != 200 or headers.get('X-Archive-Tag') != tag or headers.get('X-Source-Sha') != source_sha
                    or not SHA.fullmatch(digest) or not re.fullmatch(r'[1-9][0-9]{0,9}', length)
                    or not 1024 <= int(length) <= MAX_BYTES):
                raise TransportError('archive_status_mismatch')
        return {'archive_key': expected_archive_key(tag), 'archive_sha256': digest, 'archive_size': int(length)}

    def signed_status(self, job):
        """Return stored signed metadata for a live lease, or None when the Worker reports state missing."""
        validate_job(job, int(self.now()))
        release = job['release']
        headers = {'X-Signing-Lease': job['lease_token'], 'X-Release-Tag': release['tag'], 'X-Source-Sha': release['source_sha'],
                   'X-Archive-Sha256': release['archive_sha256'], 'X-Expected-Artifact-Key': job['expected_artifact_key']}
        data = self._parse(self._open(EDGE + '/signed/status/' + job['job_id'], headers=headers))
        if data.get('state') == 'missing':
            return None
        expected = {'job_id': job['job_id'], 'release_tag': release['tag'], 'source_sha': release['source_sha'],
                    'archive_sha256': release['archive_sha256'], 'artifact_key': job['expected_artifact_key']}
        if data.get('state') != 'ready' or any(data.get(k) != v for k, v in expected.items()):
            raise TransportError('signed_status_mismatch')
        now = self.now()
        if (not SHA.fullmatch(str(data.get('artifact_sha256'))) or type(data.get('artifact_size')) is not int
                or not 1024 <= data['artifact_size'] <= MAX_BYTES or type(data.get('artifact_expires_at')) is not int
                or not now + 60 < data['artifact_expires_at'] <= now + SIGNED_TTL
                or not isinstance(data.get('apple_device_resource_id'), str) or not RESOURCE_RE.fullmatch(data['apple_device_resource_id'])):
            raise TransportError('signed_status_invalid')
        return {k: data[k] for k in ['artifact_key', 'artifact_sha256', 'artifact_size', 'artifact_expires_at', 'apple_device_resource_id']}

    def _upload(self, path, payload, file_path, digest, size, lease=None):
        if file_path.is_symlink() or not file_path.is_file() or not 1024 <= size <= MAX_BYTES or file_path.stat().st_size != size or not SHA.fullmatch(digest) or file_digest(file_path) != digest:
            raise TransportError('signing_file_changed')
        session = self._json(path + '/sessions', payload)
        identifier = session.get('id', '')
        if not isinstance(identifier, str) or not SESSION.fullmatch(identifier) or session.get('max_part_bytes') != PART_BYTES or session.get('state') not in ['uploading', 'ready']:
            raise TransportError('upload_session_invalid')
        headers = {'X-Signing-Lease': lease} if lease else {}
        if session['state'] != 'ready':
            total, written_digest = 0, hashlib.sha256()
            with file_path.open('rb') as stream:
                part = 0
                while True:
                    data = stream.read(PART_BYTES)
                    if not data:
                        break
                    part += 1
                    total += len(data)
                    if total > size:
                        raise TransportError('signing_file_changed')
                    written_digest.update(data)
                    self._json(path + '/sessions/' + identifier + '/parts/' + str(part), data, 'PUT',
                               {**headers, 'X-Final-Part': 'true' if total == size else 'false',
                                'X-Content-Sha256': hashlib.sha256(data).hexdigest()}, binary=True)
            if total != size or written_digest.hexdigest() != digest:
                raise TransportError('signing_file_changed')
        result = self._json(path + '/sessions/' + identifier + '/complete', {}, headers=headers)
        prefix = 'archive' if path.endswith('/archives') else 'artifact'
        expected_key = payload.get('archive_key', payload.get('expected_artifact_key'))
        if result.get('state') != 'ready' or result.get(prefix + '_key') != expected_key or result.get(prefix + '_sha256') != digest or result.get(prefix + '_size') != size:
            raise TransportError('upload_attestation_mismatch')
        return result

    def upload_archive(self, file_path: Path, tag, source_sha, build):
        if file_path.is_symlink() or not file_path.is_file():
            raise TransportError('signing_file_changed')
        secret = self.authorize_archive(tag, source_sha, build)
        digest, size = file_digest(file_path), file_path.stat().st_size
        key = expected_archive_key(tag)
        expiry = int(self.now()) + 300
        message = ':'.join(map(str, ['zolnit-apple-archive-v1', tag, source_sha, build, key, digest, size, expiry]))
        payload = {'schema_version': 1, 'tag': tag, 'source_sha': source_sha, 'build': build,
                   'archive_key': key, 'archive_sha256': digest, 'archive_size': size,
                   'grant_expires_at': expiry, 'origin_grant': proof(secret, message)}
        return self._upload(EDGE + '/archives', payload, file_path, digest, size)

    def upload_signed(self, job, file_path: Path, digest: str, size: int, expires_at: int, apple_device_resource_id=None):
        validate_job(job, int(self.now()))
        if type(expires_at) is not int or not self.now() + 60 < expires_at <= self.now() + SIGNED_TTL:
            raise TransportError('artifact_expiry_invalid')
        if apple_device_resource_id is not None and (not isinstance(apple_device_resource_id, str) or len(apple_device_resource_id) > 64 or not RESOURCE_RE.fullmatch(apple_device_resource_id)):
            raise TransportError('apple_device_resource_invalid')
        release = job['release']
        secret = self.authorize_archive(release['tag'], release['source_sha'], release['build'])
        lease_hash = hashlib.sha256(job['lease_token'].encode()).hexdigest()
        message = ':'.join(map(str, ['zolnit-apple-sign-v1', job['job_id'], lease_hash, job['lease_expires_at'],
                                  release['tag'], release['source_sha'], release['build'], release['archive_sha256'], job['expected_artifact_key']]))
        payload = {'schema_version': 1, 'job_id': job['job_id'], 'lease_token': job['lease_token'],
                   'lease_expires_at': job['lease_expires_at'], 'team_id': job['team_id'], 'bundle_id': job['bundle_id'],
                   'release_tag': release['tag'], 'source_sha': release['source_sha'], 'build': release['build'],
                   'archive_sha256': release['archive_sha256'], 'expected_artifact_key': job['expected_artifact_key'],
                   'artifact_sha256': digest, 'artifact_size': size, 'artifact_expires_at': expires_at,
                   'origin_grant': proof(secret, message)}
        if apple_device_resource_id is not None:
            payload['apple_device_resource_id'] = apple_device_resource_id
        result = self._upload(EDGE + '/signed', payload, file_path, digest, size, job['lease_token'])
        if result.get('artifact_key') != job['expected_artifact_key'] or result.get('artifact_expires_at') != expires_at:
            raise TransportError('upload_attestation_mismatch')
        return {'artifact_key': result['artifact_key'], 'sha256': digest, 'size': size, 'expires_at': expires_at}

    def download_archive(self, release, destination: Path):
        tag, expected, size = release['tag'], release['archive_sha256'], release['archive_size']
        if not isinstance(tag, str) or not TAG.fullmatch(tag) or not SHA.fullmatch(expected) or type(size) is not int or not 1024 <= size <= MAX_BYTES:
            raise TransportError('archive_metadata_invalid')
        created = False
        try:
            with self._open(EDGE + '/archives/' + tag, headers={'X-Expected-Archive-Sha256': expected}) as response:
                if response.status != 200 or response.headers.get('X-Archive-Sha256') != expected or response.headers.get('X-Archive-Tag') != tag or response.headers.get('X-Source-Sha') != release['source_sha'] or response.headers.get('Content-Length') != str(size):
                    raise TransportError('archive_response_invalid')
                fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
                created = True
                digest, count = hashlib.sha256(), 0
                with os.fdopen(fd, 'wb') as output:
                    while True:
                        block = response.read(1024 * 1024)
                        if not block:
                            break
                        count += len(block)
                        if count > size:
                            raise TransportError('archive_size_mismatch')
                        output.write(block)
                        digest.update(block)
                if count != size or digest.hexdigest() != expected:
                    raise TransportError('archive_digest_mismatch')
        except Exception:
            if created:
                destination.unlink(missing_ok=True)
            raise
        return destination
