"""Scoped Apple device/profile adapter for the opt-in device signing runner."""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

from apple_distribution import TARGET_BUNDLE_IDS, read_profile, run_argv

API_ORIGIN = 'https://api.appstoreconnect.apple.com'
UDID_RE = re.compile(r'^(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})$')
OPAQUE_RE = re.compile(r'^[a-f0-9]{32}$')
RESOURCE_RE = re.compile(r'^[A-Za-z0-9-]{1,128}$')
SHA_RE = re.compile(r'^[a-f0-9]{64}$')


class ProvisioningError(RuntimeError):
    pass


def _b64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode('ascii')


def _der(data: bytes, offset: int, tag: int) -> tuple[bytes, int]:
    if offset + 2 > len(data) or data[offset] != tag:
        raise ProvisioningError('invalid_ecdsa_signature')
    offset += 1
    size = data[offset]
    offset += 1
    if size & 128:
        count = size & 127
        if not 1 <= count <= 2 or offset + count > len(data):
            raise ProvisioningError('invalid_ecdsa_length')
        size = int.from_bytes(data[offset:offset + count], 'big')
        offset += count
    if offset + size > len(data):
        raise ProvisioningError('truncated_ecdsa_signature')
    return data[offset:offset + size], offset + size


def apple_jwt(key_path: Path, key_id: str, issuer_id: str, now: int | None = None) -> str:
    if not key_path.is_absolute() or key_path.is_symlink() or not key_path.is_file() or key_path.stat().st_mode & 0o077:
        raise ProvisioningError('api_key_permissions_invalid')
    if not re.fullmatch(r'[A-Z0-9]{10}', key_id) or not re.fullmatch(r'[0-9a-fA-F-]{36}', issuer_id):
        raise ProvisioningError('api_identity_invalid')
    timestamp = int(time.time()) if now is None else now
    header = _b64(json.dumps({'alg': 'ES256', 'kid': key_id, 'typ': 'JWT'}, separators=(',', ':')).encode())
    claims = _b64(json.dumps({'iss': issuer_id, 'iat': timestamp - 5, 'exp': timestamp + 300,
                             'aud': 'appstoreconnect-v1'}, separators=(',', ':')).encode())
    message = (header + '.' + claims).encode()
    result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(key_path)],
                            input=message, capture_output=True)
    if result.returncode:
        raise ProvisioningError('api_jwt_signing_failed')
    sequence, end = _der(result.stdout, 0, 0x30)
    if end != len(result.stdout):
        raise ProvisioningError('ecdsa_trailing_data')
    r, offset = _der(sequence, 0, 0x02)
    s, offset = _der(sequence, offset, 0x02)
    if offset != len(sequence):
        raise ProvisioningError('ecdsa_trailing_data')
    try:
        signature = int.from_bytes(r, 'big').to_bytes(32, 'big') + int.from_bytes(s, 'big').to_bytes(32, 'big')
    except OverflowError as error:
        raise ProvisioningError('ecdsa_invalid_integer') from error
    return header + '.' + claims + '.' + _b64(signature)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ProvisioningError('api_redirect_rejected')


class AppleAPI:
    def __init__(self, token_factory, opener=None):
        self.token_factory = token_factory
        self.opener = opener or urllib.request.build_opener(NoRedirect())

    def request(self, path: str, payload=None, method: str = 'GET') -> dict:
        if not path.startswith('/v1/') or any(c in path for c in ['\r', '\n', '#', '\\']):
            raise ProvisioningError('api_path_rejected')
        body = json.dumps(payload).encode() if payload is not None else None
        request = urllib.request.Request(API_ORIGIN + path, data=body, method=method,
                                         headers={'Authorization': 'Bearer ' + self.token_factory(),
                                                  'Content-Type': 'application/json', 'Accept': 'application/json',
                                                  'User-Agent': 'ZolNit-Apple-Device-Signer/1'})
        try:
            with self.opener.open(request, timeout=30) as response:
                if response.geturl() != API_ORIGIN + path:
                    raise ProvisioningError('api_redirect_rejected')
                raw = response.read(4 * 1024 * 1024 + 1)
                if len(raw) > 4 * 1024 * 1024:
                    raise ProvisioningError('api_response_too_large')
                return json.loads(raw)
        except urllib.error.HTTPError as error:
            raise ProvisioningError('apple_api_http_' + str(error.code)) from None
        except (urllib.error.URLError, json.JSONDecodeError):
            raise ProvisioningError('apple_api_unavailable') from None

    def rows(self, path: str):
        seen = set()
        for _ in range(20):
            if path in seen:
                raise ProvisioningError('api_pagination_loop')
            seen.add(path)
            value = self.request(path)
            rows = value.get('data')
            if not isinstance(rows, list):
                raise ProvisioningError('api_list_invalid')
            yield from rows
            link = value.get('links', {}).get('next')
            if not link:
                return
            parsed = urllib.parse.urlsplit(link)
            if parsed.scheme != 'https' or parsed.netloc != 'api.appstoreconnect.apple.com' or parsed.fragment:
                raise ProvisioningError('api_pagination_origin_rejected')
            path = parsed.path + ('?' + parsed.query if parsed.query else '')
        raise ProvisioningError('api_pagination_limit')


def ensure_device(api: AppleAPI, device: dict) -> str:
    opaque = device.get('device_id', '')
    udid = device.get('udid', '')
    if not isinstance(opaque, str) or not OPAQUE_RE.fullmatch(opaque) or not isinstance(udid, str) or not UDID_RE.fullmatch(udid):
        raise ProvisioningError('device_job_invalid')
    matches = [row for row in api.rows('/v1/devices?limit=200')
               if str(row.get('attributes', {}).get('udid', '')).upper() == udid.upper()]
    if len(matches) > 1:
        raise ProvisioningError('device_identity_ambiguous')
    if matches:
        row = matches[0]
        if row.get('attributes', {}).get('status') != 'ENABLED' or row.get('attributes', {}).get('platform') != 'IOS':
            raise ProvisioningError('device_disabled_or_wrong_platform')
    else:
        value = api.request('/v1/devices', {'data': {'type': 'devices', 'attributes': {
            'name': 'ZolNit ' + opaque[:12], 'platform': 'IOS', 'udid': udid}}}, method='POST')
        row = value.get('data', {})
        if str(row.get('attributes', {}).get('udid', '')).upper() != udid.upper() or row.get('attributes', {}).get('status') != 'ENABLED':
            raise ProvisioningError('registered_device_mismatch')
    identifier = row.get('id', '')
    if not isinstance(identifier, str) or not RESOURCE_RE.fullmatch(identifier):
        raise ProvisioningError('device_resource_invalid')
    return identifier


def ensure_profile(api: AppleAPI, target: str, bundle_resource: str, certificate_resource: str,
                   device_resource: str, opaque_device: str, build: int, udid: str,
                   certificate_sha256: str, directory: Path, runner=run_argv):
    if target not in TARGET_BUNDLE_IDS or not all(RESOURCE_RE.fullmatch(x) for x in [bundle_resource, certificate_resource, device_resource]):
        raise ProvisioningError('profile_resources_invalid')
    if not OPAQUE_RE.fullmatch(opaque_device) or not isinstance(build, int) or build < 1 or not SHA_RE.fullmatch(certificate_sha256) or not UDID_RE.fullmatch(udid):
        raise ProvisioningError('profile_job_invalid')
    name = 'ZolNit ' + target + ' ' + opaque_device[:12] + ' ' + str(build)
    path = '/v1/profiles?' + urllib.parse.urlencode({'filter[name]': name, 'limit': 100})
    matches = [row for row in api.rows(path) if row.get('attributes', {}).get('name') == name and
               row.get('attributes', {}).get('profileType') == 'IOS_APP_ADHOC' and
               row.get('attributes', {}).get('profileState') == 'ACTIVE']
    if len(matches) > 1:
        raise ProvisioningError('profile_identity_ambiguous')
    if matches:
        row = matches[0]
    else:
        value = api.request('/v1/profiles', {'data': {'type': 'profiles',
            'attributes': {'name': name, 'profileType': 'IOS_APP_ADHOC'},
            'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bundle_resource}},
                              'certificates': {'data': [{'type': 'certificates', 'id': certificate_resource}]},
                              'devices': {'data': [{'type': 'devices', 'id': device_resource}]}}}}, method='POST')
        row = value.get('data', {})
    attributes = row.get('attributes', {})
    if attributes.get('profileState') != 'ACTIVE' or attributes.get('profileType') != 'IOS_APP_ADHOC':
        raise ProvisioningError('profile_state_invalid')
    try:
        raw = base64.b64decode(attributes['profileContent'], validate=True)
    except (KeyError, ValueError, TypeError):
        raise ProvisioningError('profile_content_invalid') from None
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if directory.is_symlink() or directory.stat().st_mode & 0o077:
        raise ProvisioningError('profile_directory_permissions_invalid')
    profile_path = directory / (target + '.mobileprovision')
    fd = os.open(profile_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(raw)
    digest = hashlib.sha256(raw).hexdigest()
    profile = read_profile(target, profile_path, digest, runner, distribution='release-testing',
                           execute=True, require_trusted_hash=True)
    import apple_distribution
    payload = apple_distribution.profile_plist(profile_path, runner, execute=True)
    if udid.upper() not in [str(x).upper() for x in payload.get('ProvisionedDevices', [])]:
        raise ProvisioningError('profile_does_not_authorize_device')
    if certificate_sha256 not in [hashlib.sha256(x).hexdigest() for x in payload.get('DeveloperCertificates', []) if isinstance(x, bytes)]:
        raise ProvisioningError('profile_certificate_mismatch')
    return profile
