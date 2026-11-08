#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

WRAPPER_PROPERTIES = Path('android/gradle/wrapper/gradle-wrapper.properties')
EXPECTED_VERSION = '9.8.0'
EXPECTED_ZIP_NAME = f'gradle-{EXPECTED_VERSION}-all.zip'
EXPECTED_DIST_STEM = f'gradle-{EXPECTED_VERSION}-all'
EXPECTED_WRAPPER_URL = f'https://services.gradle.org/distributions/{EXPECTED_ZIP_NAME}'
EXPECTED_REPO = 'gradle/gradle-distributions'
EXPECTED_TAG = f'v{EXPECTED_VERSION}'
EXPECTED_ASSET_ID = 586068849
EXPECTED_SIZE = 264624798
EXPECTED_SHA256 = '46ac66d47f30f3dacfdf306e0b714a91a34fb94a22ba0a744b280933f47bc0cf'
EXPECTED_API_HOST = 'api.github.com'
EXPECTED_ASSET_API_URL = f'https://{EXPECTED_API_HOST}/repos/{EXPECTED_REPO}/releases/assets/{EXPECTED_ASSET_ID}'
ALLOWED_REDIRECT_HOSTS = frozenset({
    'api.github.com',
    'github.com',
    'objects.githubusercontent.com',
    'release-assets.githubusercontent.com',
    'github-releases.githubusercontent.com',
})
USER_AGENT = 'ZolNit/GradlePrefetch'


class PrefetchError(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PrefetchError(message)


def wrapper_url_hash(distribution_url: str) -> str:
    digest = hashlib.md5(distribution_url.encode('utf-8')).digest()
    value = int.from_bytes(digest, 'big', signed=False)
    alphabet = '0123456789abcdefghijklmnopqrstuvwxyz'
    if value == 0:
        return '0'
    chars = []
    while value:
        value, remainder = divmod(value, 36)
        chars.append(alphabet[remainder])
    return ''.join(reversed(chars))


def parse_wrapper_properties(path: Path) -> dict[str, str]:
    require(path.is_file(), f'wrapper properties not found: {path}')
    props: dict[str, str] = {}
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or line.startswith('!'):
            continue
        sep = '=' if '=' in line else (':' if ':' in line else None)
        require(sep is not None, f'malformed wrapper property line: {raw!r}')
        key, value = line.split(sep, 1)
        props[key.strip()] = value.strip().replace(r'\:', ':').replace(r'\=', '=')
    return props


def verify_wrapper_contract(props: dict[str, str]) -> str:
    require(props.get('distributionBase') == 'GRADLE_USER_HOME',
            f"unexpected distributionBase: {props.get('distributionBase')!r}")
    require(props.get('distributionPath') == 'wrapper/dists',
            f"unexpected distributionPath: {props.get('distributionPath')!r}")
    require(props.get('zipStoreBase') == 'GRADLE_USER_HOME',
            f"unexpected zipStoreBase: {props.get('zipStoreBase')!r}")
    require(props.get('zipStorePath') == 'wrapper/dists',
            f"unexpected zipStorePath: {props.get('zipStorePath')!r}")
    url = props.get('distributionUrl', '')
    require(url == EXPECTED_WRAPPER_URL,
            f'wrapper distributionUrl {url!r} does not match pinned {EXPECTED_WRAPPER_URL!r}')
    if 'distributionSha256Sum' in props:
        require(props['distributionSha256Sum'].lower() == EXPECTED_SHA256,
                f"wrapper distributionSha256Sum {props['distributionSha256Sum']!r} mismatches pinned SHA256")
    return url


def verify_archive(path: Path, expected_size: int = EXPECTED_SIZE, expected_sha256: str = EXPECTED_SHA256) -> str:
    require(path.is_file(), f'archive missing: {path}')
    size = path.stat().st_size
    require(size == expected_size, f'archive size {size} does not match expected {expected_size}')
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    actual_sha = digest.hexdigest()
    require(actual_sha == expected_sha256.lower(),
            f'archive sha256 {actual_sha} does not match expected {expected_sha256}')
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            require(bool(names), 'archive is empty')
            prefix = f'gradle-{EXPECTED_VERSION}/'
            for name in names:
                normalized = name.replace('\\', '/')
                require(not normalized.startswith('/') and '..' not in normalized.split('/'),
                        f'unsafe zip entry path: {name!r}')
                require(normalized.startswith(prefix),
                        f'unexpected root in zip entry: {name!r}')
            require(f'{prefix}bin/gradle' in names, f'archive lacks {prefix}bin/gradle')
    except zipfile.BadZipFile as error:
        raise PrefetchError(f'corrupt zip archive: {error}') from error
    return actual_sha


def validate_source_url(url: str, allow_redirect_hosts: bool = False) -> urllib.parse.ParseResult:
    parsed = urllib.parse.urlparse(url)
    host = (parsed.hostname or '').lower()
    require(parsed.scheme == 'https', f'source URL must use https: {url}')
    require(not parsed.username and not parsed.password, 'source URL must not embed credentials')
    if allow_redirect_hosts:
        require(host in ALLOWED_REDIRECT_HOSTS, f'untrusted redirect host: {host!r}')
    else:
        require(host == EXPECTED_API_HOST and url == EXPECTED_ASSET_API_URL,
                f'untrusted source URL: {url!r}')
    return parsed


class _StripAuthRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urllib.parse.urljoin(req.full_url, newurl)
        parsed = validate_source_url(target, allow_redirect_hosts=True)
        redirected = super().redirect_request(req, fp, code, msg, headers, target)
        if redirected is None:
            return None
        if (parsed.hostname or '').lower() != EXPECTED_API_HOST:
            for header in list(redirected.headers) + list(redirected.unredirected_hdrs):
                if header.lower() == 'authorization':
                    redirected.headers.pop(header, None)
                    redirected.unredirected_hdrs.pop(header, None)
        return redirected


def build_default_opener() -> urllib.request.OpenerDirector:
    return urllib.request.build_opener(_StripAuthRedirectHandler())


def stream_github_asset(
    destination: Path,
    token: str | None = None,
    api_url: str = EXPECTED_ASSET_API_URL,
    opener=None,
    retries: int = 3,
) -> None:
    validate_source_url(api_url, allow_redirect_hosts=False)
    headers = {
        'Accept': 'application/octet-stream',
        'User-Agent': USER_AGENT,
        'X-GitHub-Api-Version': '2022-11-28',
    }
    if token:
        headers['Authorization'] = f'Bearer {token}'
    client = opener or build_default_opener()
    last_error: Exception | None = None
    for attempt in range(1, retries + 1):
        request = urllib.request.Request(api_url, headers=headers)
        try:
            with client.open(request, timeout=60) as response, destination.open('wb') as handle:
                final_url = getattr(response, 'geturl', lambda: api_url)()
                if final_url:
                    validate_source_url(final_url, allow_redirect_hosts=True)
                shutil.copyfileobj(response, handle, length=1024 * 1024)
            return
        except (OSError, urllib.error.URLError, PrefetchError) as error:
            last_error = error
            if isinstance(error, PrefetchError):
                raise
            if attempt < retries:
                time.sleep(min(2 * attempt, 5))
    raise PrefetchError(f'failed to download official Gradle asset after {retries} attempts: {last_error}')


def resolve_gradle_user_home(env: dict[str, str], explicit: Path | None = None) -> Path:
    if explicit is not None:
        return explicit
    configured = env.get('GRADLE_USER_HOME', '').strip()
    if configured:
        return Path(configured)
    return Path.home() / '.gradle'


def prefetch_gradle(
    wrapper_properties: Path = WRAPPER_PROPERTIES,
    gradle_user_home: Path | None = None,
    fixture: Path | None = None,
    api_url: str = EXPECTED_ASSET_API_URL,
    expected_size: int = EXPECTED_SIZE,
    expected_sha256: str = EXPECTED_SHA256,
    env: dict[str, str] | None = None,
    opener=None,
) -> dict[str, object]:
    env_map = os.environ if env is None else env
    props = parse_wrapper_properties(wrapper_properties)
    dist_url = verify_wrapper_contract(props)
    url_hash = wrapper_url_hash(dist_url)
    home = resolve_gradle_user_home(env_map, gradle_user_home)
    target_dir = home / 'wrapper' / 'dists' / EXPECTED_DIST_STEM / url_hash
    target_zip = target_dir / EXPECTED_ZIP_NAME
    ok_marker = target_dir / f'{EXPECTED_ZIP_NAME}.ok'
    part_file = target_dir / f'{EXPECTED_ZIP_NAME}.part'

    target_dir.mkdir(parents=True, exist_ok=True)
    if target_zip.exists():
        try:
            if not target_zip.is_file():
                raise PrefetchError('cached target path is not a regular file')
            verify_archive(target_zip, expected_size=expected_size, expected_sha256=expected_sha256)
            return {
                'status': 'cached',
                'version': EXPECTED_VERSION,
                'url_hash': url_hash,
                'zip': str(target_zip),
                'size': expected_size,
                'sha256': expected_sha256,
            }
        except PrefetchError:
            for child in target_dir.iterdir():
                if child.is_dir():
                    shutil.rmtree(child, ignore_errors=True)
                elif child.name in (EXPECTED_ZIP_NAME, ok_marker.name, part_file.name):
                    child.unlink(missing_ok=True)

    if fixture is not None:
        require(fixture.is_file(), f'fixture archive not found: {fixture}')
    else:
        validate_source_url(api_url, allow_redirect_hosts=False)

    fd, temp_name = tempfile.mkstemp(prefix=f'.{EXPECTED_ZIP_NAME}.', suffix='.tmp', dir=str(target_dir))
    os.close(fd)
    temp_path = Path(temp_name)
    try:
        if fixture is not None:
            shutil.copyfile(fixture, temp_path)
        else:
            token = (env_map.get('GH_TOKEN') or env_map.get('GITHUB_TOKEN') or '').strip() or None
            stream_github_asset(temp_path, token=token, api_url=api_url, opener=opener)
        verify_archive(temp_path, expected_size=expected_size, expected_sha256=expected_sha256)
        for child in target_dir.iterdir():
            if child == temp_path:
                continue
            if child.is_dir():
                shutil.rmtree(child, ignore_errors=True)
            elif child.name in (ok_marker.name, part_file.name):
                child.unlink(missing_ok=True)
        os.replace(temp_path, target_zip)
    finally:
        if temp_path.exists():
            temp_path.unlink(missing_ok=True)

    return {
        'status': 'prefetched',
        'version': EXPECTED_VERSION,
        'url_hash': url_hash,
        'zip': str(target_zip),
        'size': expected_size,
        'sha256': expected_sha256,
    }


def main(argv: list[str] | None = None, env: dict[str, str] | None = None) -> int:
    parser = argparse.ArgumentParser(description='Prefetch pinned Gradle distribution from official GitHub release asset.')
    parser.add_argument('--wrapper-properties', type=Path, default=WRAPPER_PROPERTIES)
    parser.add_argument('--gradle-user-home', type=Path, default=None)
    parser.add_argument('--fixture', type=Path, default=None)
    parser.add_argument('--api-url', default=EXPECTED_ASSET_API_URL)
    args = parser.parse_args(argv)
    try:
        result = prefetch_gradle(
            wrapper_properties=args.wrapper_properties,
            gradle_user_home=args.gradle_user_home,
            fixture=args.fixture,
            api_url=args.api_url,
            env=env,
        )
    except (PrefetchError, OSError, ValueError) as error:
        print(f'::error::{error}', file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
