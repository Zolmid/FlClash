"""GitHub OIDC identity and restricted configuration for the Apple device signer."""
from __future__ import annotations

import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from apple_distribution import TARGET_BUNDLE_IDS, TEAM_ID
from device_provisioning import RESOURCE_RE, SHA_RE, ProvisioningError

AUDIENCE = 'zolnit-apple-device-signer'
ISSUER = 'https://token.actions.githubusercontent.com'
TOKEN_HOST_SUFFIX = '.actions.githubusercontent.com'
REFRESH_MARGIN_SECONDS = 120
CONFIG_KEYS = {'schema_version', 'team_id', 'api_key_path', 'api_key_id', 'api_issuer_id', 'signing_keychain',
               'signing_identity', 'certificate_resource_id', 'certificate_sha256', 'bundle_resource_ids'}
PEM_RE = re.compile(r'-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+?)-----END CERTIFICATE-----')


class ConfigError(ProvisioningError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        raise ConfigError('oidc_redirect_rejected')


def _claims(token: str) -> dict:
    parts = token.split('.')
    if len(parts) != 3 or not all(re.fullmatch(r'[A-Za-z0-9_-]+', part) for part in parts):
        raise ConfigError('oidc_token_invalid')
    try:
        value = json.loads(base64.urlsafe_b64decode(parts[1] + '=' * (-len(parts[1]) % 4)))
    except (binascii.Error, ValueError, UnicodeError):
        raise ConfigError('oidc_token_invalid') from None
    if not isinstance(value, dict):
        raise ConfigError('oidc_token_invalid')
    return value


class GitHubOIDC:
    """Token factory for SigningTransport; the request token is sent only as a header."""

    def __init__(self, environ=None, opener=None, now=time.time, host_suffix=TOKEN_HOST_SUFFIX):
        env = os.environ if environ is None else environ
        endpoint = env.get('ACTIONS_ID_TOKEN_REQUEST_URL', '')
        request_token = env.get('ACTIONS_ID_TOKEN_REQUEST_TOKEN', '')
        try:
            parts = urllib.parse.urlsplit(endpoint)
            port = parts.port
        except ValueError:
            raise ConfigError('oidc_endpoint_invalid') from None
        host = (parts.hostname or '').lower()
        if (parts.scheme != 'https' or not host.endswith(host_suffix) or parts.username is not None
                or parts.password is not None or parts.fragment or port not in (None, 443)
                or any(c in endpoint for c in '\r\n\0 \\')):
            raise ConfigError('oidc_endpoint_invalid')
        query = urllib.parse.parse_qsl(parts.query, keep_blank_values=True)
        if any(key == 'audience' for key, _ in query):
            raise ConfigError('oidc_endpoint_invalid')
        if not request_token or len(request_token) > 16384 or any(c in request_token for c in '\r\n\0'):
            raise ConfigError('oidc_request_token_missing')
        self._url = urllib.parse.urlunsplit(('https', parts.netloc, parts.path,
                                             urllib.parse.urlencode(query + [('audience', AUDIENCE)]), ''))
        self._request_token = request_token
        self.opener = opener or urllib.request.build_opener(NoRedirect())
        self.now = now
        self._lock = threading.Lock()
        self._token = None
        self._expires = 0
        self.fetches = 0

    def __call__(self) -> str:
        with self._lock:
            if self._token is None or self._expires - self.now() <= REFRESH_MARGIN_SECONDS:
                self._token, self._expires = self._fetch()
            return self._token

    def _fetch(self):
        request = urllib.request.Request(self._url, headers={
            'Authorization': 'Bearer ' + self._request_token, 'Accept': 'application/json; api-version=2.0',
            'User-Agent': 'ZolNit-Apple-Signer/1'})
        self.fetches += 1
        try:
            with self.opener.open(request, timeout=30) as response:
                if response.geturl() != self._url:
                    raise ConfigError('oidc_redirect_rejected')
                if response.status != 200:
                    raise ConfigError('oidc_response_invalid')
                raw = response.read(65537)
        except urllib.error.HTTPError as error:
            raise ConfigError('oidc_http_' + str(error.code)) from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise ConfigError('oidc_unavailable') from None
        if len(raw) > 65536:
            raise ConfigError('oidc_response_too_large')
        try:
            token = json.loads(raw).get('value')
        except (ValueError, UnicodeError, AttributeError):
            raise ConfigError('oidc_response_invalid') from None
        if not isinstance(token, str) or not 1 <= len(token) <= 16384:
            raise ConfigError('oidc_response_invalid')
        claims = _claims(token)
        audience = claims.get('aud')
        current = int(self.now())
        if audience != AUDIENCE and not (isinstance(audience, list) and AUDIENCE in audience):
            raise ConfigError('oidc_audience_mismatch')
        if claims.get('iss') != ISSUER:
            raise ConfigError('oidc_issuer_mismatch')
        expires = claims.get('exp')
        if type(expires) is not int or not current + 60 < expires <= current + 86400:
            raise ConfigError('oidc_token_expiry_invalid')
        if any(type(claims.get(k)) is int and claims[k] > current + 60 for k in ['iat', 'nbf']):
            raise ConfigError('oidc_token_not_yet_valid')
        return token, expires


def _absolute_file(value, label: str, private: bool) -> Path:
    if not isinstance(value, str) or not value.startswith('/') or any(c in value for c in '\r\n\0'):
        raise ConfigError(label + '_invalid')
    path = Path(value)
    if path.is_symlink() or not path.is_file() or (private and path.stat().st_mode & 0o077):
        raise ConfigError(label + '_invalid')
    return path


def load_config(path: Path) -> dict:
    if not path.is_absolute():
        raise ConfigError('signer_config_path_invalid')
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    except OSError:
        raise ConfigError('signer_config_unreadable') from None
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_uid != os.getuid() or info.st_size > 16384:
            raise ConfigError('signer_config_permissions_invalid')
        raw = stream.read(16385)
    try:
        data = json.loads(raw)
    except (ValueError, UnicodeError):
        raise ConfigError('signer_config_invalid') from None
    if not isinstance(data, dict) or set(data) != CONFIG_KEYS or data['schema_version'] != 1 or data['team_id'] != TEAM_ID:
        raise ConfigError('signer_config_schema_invalid')
    if not isinstance(data['api_key_id'], str) or not re.fullmatch(r'[A-Z0-9]{10}', data['api_key_id']):
        raise ConfigError('api_key_id_invalid')
    if not isinstance(data['api_issuer_id'], str) or not re.fullmatch(r'[0-9a-fA-F-]{36}', data['api_issuer_id']):
        raise ConfigError('api_issuer_id_invalid')
    if not isinstance(data['signing_identity'], str) or not re.fullmatch(r'[0-9A-F]{40}', data['signing_identity']):
        raise ConfigError('signing_identity_invalid')
    if not isinstance(data['certificate_resource_id'], str) or not RESOURCE_RE.fullmatch(data['certificate_resource_id']):
        raise ConfigError('certificate_resource_id_invalid')
    if not isinstance(data['certificate_sha256'], str) or not SHA_RE.fullmatch(data['certificate_sha256']):
        raise ConfigError('certificate_sha256_invalid')
    resources = data['bundle_resource_ids']
    if (not isinstance(resources, dict) or set(resources) != set(TARGET_BUNDLE_IDS)
            or not all(isinstance(v, str) and RESOURCE_RE.fullmatch(v) for v in resources.values())
            or len(set(resources.values())) != len(resources)):
        raise ConfigError('bundle_resource_ids_invalid')
    return {**data, 'api_key_path': _absolute_file(data['api_key_path'], 'api_key_path', True),
            'signing_keychain': _absolute_file(data['signing_keychain'], 'signing_keychain', False),
            'bundle_resource_ids': dict(resources)}


def verify_signing_identity(config: dict, runner) -> None:
    keychain = str(config['signing_keychain'])
    identity = config['signing_identity']
    listed = runner(['security', 'find-identity', '-v', '-p', 'codesigning', keychain]).stdout
    if identity not in re.findall(r'\b([0-9A-F]{40})\b', listed):
        raise ConfigError('signing_identity_missing')
    certificates = runner(['security', 'find-certificate', '-a', '-p', keychain]).stdout
    for block in PEM_RE.findall(certificates):
        try:
            der = base64.b64decode(''.join(block.split()), validate=True)
        except binascii.Error:
            continue
        if hashlib.sha1(der).hexdigest().upper() == identity:
            if hashlib.sha256(der).hexdigest() != config['certificate_sha256']:
                raise ConfigError('signing_certificate_mismatch')
            return
    raise ConfigError('signing_certificate_missing')
