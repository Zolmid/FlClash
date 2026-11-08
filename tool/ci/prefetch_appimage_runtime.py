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

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prefetch_gradle import (
    EXPECTED_API_HOST,
    PrefetchError,
    require,
    stream_github_asset,
    validate_source_url,
)

EXPECTED_REPO = 'AppImage/type2-runtime'
EXPECTED_TAG = '20251108'
EXPECTED_ASSET_NAME = 'runtime-x86_64'
EXPECTED_ASSET_ID = 326011592
EXPECTED_SIZE = 944632
EXPECTED_SHA256 = '2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d'
EXPECTED_ASSET_API_URL = f'https://{EXPECTED_API_HOST}/repos/{EXPECTED_REPO}/releases/assets/{EXPECTED_ASSET_ID}'
ELF_MAGIC = b'\x7fELF'


def verify_runtime(
    path: Path,
    expected_size: int = EXPECTED_SIZE,
    expected_sha256: str = EXPECTED_SHA256,
) -> str:
    require(path.is_file(), f'AppImage runtime missing: {path}')
    size = path.stat().st_size
    require(size == expected_size, f'AppImage runtime size {size} does not match expected {expected_size}')
    digest = hashlib.sha256()
    header = b''
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(256 * 1024), b''):
            if not header:
                header = chunk[:4]
            digest.update(chunk)
    require(header == ELF_MAGIC, 'AppImage runtime is not an ELF binary')
    actual_sha = digest.hexdigest()
    require(actual_sha == expected_sha256.lower(),
            f'AppImage runtime sha256 {actual_sha} does not match expected {expected_sha256}')
    return actual_sha


def prefetch_appimage_runtime(
    output: Path,
    fixture: Path | None = None,
    api_url: str = EXPECTED_ASSET_API_URL,
    expected_size: int = EXPECTED_SIZE,
    expected_sha256: str = EXPECTED_SHA256,
    env: dict[str, str] | None = None,
    opener=None,
) -> dict[str, object]:
    env_map = os.environ if env is None else env
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        try:
            if not output.is_file():
                raise PrefetchError('cached AppImage runtime path is not a regular file')
            verify_runtime(output, expected_size=expected_size, expected_sha256=expected_sha256)
            return {
                'status': 'cached',
                'tag': EXPECTED_TAG,
                'asset': EXPECTED_ASSET_NAME,
                'path': str(output),
                'size': expected_size,
                'sha256': expected_sha256,
            }
        except PrefetchError:
            if output.is_dir():
                shutil.rmtree(output, ignore_errors=True)
            else:
                output.unlink(missing_ok=True)

    if fixture is not None:
        require(fixture.is_file(), f'fixture runtime not found: {fixture}')
    else:
        validate_source_url(api_url, allow_redirect_hosts=False, expected_api_url=EXPECTED_ASSET_API_URL)

    fd, temp_name = tempfile.mkstemp(prefix=f'.{EXPECTED_ASSET_NAME}.', suffix='.tmp', dir=str(output.parent))
    os.close(fd)
    temp_path = Path(temp_name)
    try:
        if fixture is not None:
            shutil.copyfile(fixture, temp_path)
        else:
            token = (env_map.get('GH_TOKEN') or env_map.get('GITHUB_TOKEN') or '').strip() or None
            stream_github_asset(
                temp_path,
                token=token,
                api_url=api_url,
                expected_api_url=EXPECTED_ASSET_API_URL,
                opener=opener,
            )
        verify_runtime(temp_path, expected_size=expected_size, expected_sha256=expected_sha256)
        os.chmod(temp_path, 0o755)
        os.replace(temp_path, output)
    finally:
        if temp_path.exists():
            temp_path.unlink(missing_ok=True)

    return {
        'status': 'prefetched',
        'tag': EXPECTED_TAG,
        'asset': EXPECTED_ASSET_NAME,
        'path': str(output),
        'size': expected_size,
        'sha256': expected_sha256,
    }


def main(argv: list[str] | None = None, env: dict[str, str] | None = None) -> int:
    parser = argparse.ArgumentParser(description='Prefetch pinned AppImage runtime from official GitHub release asset.')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, default=None)
    parser.add_argument('--api-url', default=EXPECTED_ASSET_API_URL)
    args = parser.parse_args(argv)
    try:
        result = prefetch_appimage_runtime(
            output=args.output,
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
