#!/usr/bin/env python3
"""Sign and notarize one verified same-run macOS build for direct distribution."""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import signal
import shutil
import subprocess
import sys
import tempfile

import assemble_release as release

MACHO_MAGIC = {bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                             'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}
BUNDLES = {'.framework', '.app', '.xpc', '.appex', '.bundle', '.plugin'}


class SigningError(Exception):
    pass


def run(args, *, stdin=None, timeout=1800):
    label = ' '.join(str(x) for x in args[:3]) if str(args[0]) == 'xcrun' else str(args[0])
    try:
        result = subprocess.run([str(a) for a in args], input=stdin, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        raise SigningError(f'{label} timed out') from error
    if result.returncode:
        raise SigningError(f'{label} failed with exit status {result.returncode}')
    return result.stdout


def security_command(*args):
    def quote(value):
        value = str(value)
        if any(c in value for c in '\r\n\0'):
            raise SigningError('invalid keychain input')
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    result = run(['security', '-i'], stdin=' '.join(quote(x) for x in args) + '\n')
    if re.search(r'(?im)^\s*security:.*(?:error|failed|invalid|not found)', result):
        raise SigningError('keychain operation failed')


def decode_secret(name, destination):
    try:
        value = base64.b64decode(os.environ[name], validate=True)
    except (KeyError, ValueError) as error:
        raise SigningError(f'{name} missing or invalid base64') from error
    if not value:
        raise SigningError(f'{name} is empty')
    destination.write_bytes(value)
    destination.chmod(0o600)


def nested_code(app):
    found = []
    main = app / 'Contents' / 'MacOS' / plistlib.loads((app / 'Contents/Info.plist').read_bytes())['CFBundleExecutable']
    for path in app.rglob('*'):
        if path.is_symlink():
            continue
        if path.is_dir() and path.suffix in BUNDLES:
            found.append(path)
        elif path.is_file() and path != main:
            with path.open('rb') as stream:
                if stream.read(4) in MACHO_MAGIC:
                    found.append(path)
    core = app / 'Contents' / 'MacOS' / 'FlClashCore'
    manifest = core.parent / 'manifest.json'
    if manifest.exists() or manifest.is_symlink():
        raise SigningError('unexpected Core manifest: macOS helper hash binding requires review')
    if any(path.name in ('ZolNitHelperService', 'FlClashHelperService') for path in found):
        raise SigningError('unexpected privileged Helper: embedded Core hash requires review')
    if not core.is_file() or core not in found:
        raise SigningError('bundled FlClashCore Mach-O is missing')
    if not main.is_file():
        raise SigningError('app executable is missing')
    return sorted(found, key=lambda p: (-len(p.parts), str(p)))


def select_identity(output, team):
    if not re.fullmatch(r'[A-Z0-9]{10}', team):
        raise SigningError('MACOS_TEAM_ID must be a ten-character Apple team ID')
    pattern = re.compile(r'^\s*\d+\) ([0-9A-F]{40}) "Developer ID Application: [^"\n]+ \(' + team + r'\)"\s*$', re.M)
    matches = pattern.findall(output)
    if len(matches) != 1:
        raise SigningError('expected exactly one valid Developer ID Application identity for the team')
    return matches[0]


def submit(path, key, key_id, issuer):
    output = run(['xcrun', 'notarytool', 'submit', path, '--key', key, '--key-id', key_id,
                  '--issuer', issuer, '--wait', '--timeout', '20m', '--output-format', 'json'], timeout=1320)
    try:
        result = json.loads(output)
    except ValueError as error:
        raise SigningError('notarytool returned invalid JSON') from error
    if result.get('status') != 'Accepted' or not isinstance(result.get('id'), str) or not result['id']:
        status = result.get('status')
        status = status if isinstance(status, str) and re.fullmatch(r'[A-Za-z ]{1,40}', status) else 'unknown'
        raise SigningError(f'{path.name} notarization not accepted: {status}')
    return result['id']


def sign_package(app, dmg, scratch, identity, key, key_id, issuer, entitlements):
    for item in nested_code(app):
        run(['codesign', '--force', '--sign', identity, '--options', 'runtime', '--timestamp', item])
    run(['codesign', '--force', '--sign', identity, '--options', 'runtime', '--timestamp',
         '--entitlements', entitlements, app])
    run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', app])
    zipped = scratch / 'notary-app.zip'
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, zipped])
    app_id = submit(zipped, key, key_id, issuer)
    run(['xcrun', 'stapler', 'staple', app])
    run(['xcrun', 'stapler', 'validate', app])
    run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', app])
    run(['spctl', '--assess', '--type', 'execute', '--verbose=2', app])
    staging = scratch / 'dmg-content'
    staging.mkdir()
    run(['ditto', app, staging / 'ZolNit.app'])
    (staging / 'Applications').symlink_to('/Applications')
    run(['hdiutil', 'create', '-volname', 'ZolNit', '-srcfolder', staging, '-format', 'UDZO', dmg])
    run(['codesign', '--force', '--sign', identity, '--timestamp', dmg])
    run(['codesign', '--verify', '--strict', '--verbose=2', dmg])
    dmg_id = submit(dmg, key, key_id, issuer)
    run(['xcrun', 'stapler', 'staple', dmg])
    run(['xcrun', 'stapler', 'validate', dmg])
    run(['codesign', '--verify', '--strict', '--verbose=2', dmg])
    run(['hdiutil', 'verify', dmg])
    run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=2', dmg])
    return app_id, dmg_id


def prepare(input_dir, output_dir, version, arch, *, context=None, entitlements=None):
    if context is None:
        context = release.Context(os.environ, '.')
    if version != context.version or arch not in ('arm64', 'x64'):
        raise SigningError('version or architecture mismatch')
    names = {p.name for p in input_dir.iterdir() if p.is_file() and not p.is_symlink()}
    listed = release.verify_sums(input_dir, names)
    release.check_provenance((input_dir / 'source-provenance.txt').read_text(), context, 'macos', arch)
    zip_name = f'FlClash-macos-{arch}-release.zip'
    if zip_name not in listed:
        raise SigningError('same-run app archive missing')
    if output_dir.exists():
        raise SigningError('output directory already exists')
    team = os.environ.get('MACOS_TEAM_ID', '')
    key_id = os.environ.get('APPLE_ASC_API_KEY_ID', '')
    issuer = os.environ.get('APPLE_ASC_ISSUER_ID', '')
    password = os.environ.get('MACOS_DEVELOPER_ID_P12_PASSWORD', '')
    if not password or not re.fullmatch(r'[A-Z0-9]{10}', key_id) or not re.fullmatch(r'[0-9a-fA-F-]{36}', issuer):
        raise SigningError('missing or invalid signing credentials')
    with tempfile.TemporaryDirectory(prefix='zolnit-macos-sign-') as temp:
        scratch = Path(temp)
        os.chmod(scratch, 0o700)
        p12, key, keychain = scratch / 'identity.p12', scratch / 'AuthKey.p8', scratch / 'signing.keychain-db'
        decode_secret('MACOS_DEVELOPER_ID_P12_BASE64', p12)
        decode_secret('APPLE_ASC_P8_BASE64', key)
        keychain_password = secrets.token_urlsafe(32)
        original = re.findall(r'"([^"\n]+)"', run(['security', 'list-keychains', '-d', 'user']))
        if not original:
            raise SigningError('could not capture the original keychain search list')
        try:
            security_command('create-keychain', '-p', keychain_password, keychain)
            security_command('unlock-keychain', '-p', keychain_password, keychain)
            security_command('import', p12, '-k', keychain, '-P', password, '-T', '/usr/bin/codesign')
            security_command('set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', keychain_password, keychain)
            run(['security', 'list-keychains', '-d', 'user', '-s', keychain, *original])
            identity = select_identity(run(['security', 'find-identity', '-v', '-p', 'codesigning', keychain]), team)
            unpacked = scratch / 'unpacked'
            unpacked.mkdir()
            run(['ditto', '-x', '-k', input_dir / zip_name, unpacked])
            app = unpacked / 'ZolNit.app'
            if not app.is_dir() or app.is_symlink():
                raise SigningError('app archive has no ZolNit.app')
            dmg_name = f'ZolNit-{version}-macos-{arch}.dmg'
            dmg = scratch / dmg_name
            app_id, dmg_id = sign_package(app, dmg, scratch, identity, key, key_id, issuer,
                                          entitlements or Path('macos/Runner/Release.entitlements'))
            if not dmg.is_file() or not dmg.stat().st_size:
                raise SigningError('final DMG is missing or empty')
            receipt = {'schema_version': 1, 'source_commit': context.sha, 'run_id': context.run_id,
                       'arch': arch, 'input_archive': zip_name, 'input_sha256': listed[zip_name],
                       'dmg': dmg_name, 'dmg_sha256': release.sha256_file(dmg),
                       'team_id': team, 'identity_sha1': identity, 'app_notary_id': app_id,
                       'dmg_notary_id': dmg_id, 'verification': 'developer-id-notarized-stapled'}
            output_dir.mkdir(parents=True)
            shutil.copyfile(dmg, output_dir / dmg_name)
            (output_dir / 'signing-receipt.json').write_text(json.dumps(receipt, sort_keys=True) + '\n')
            (output_dir / 'SHA256SUMS').write_text(''.join(
                f'{release.sha256_file(p)}  {p.name}\n' for p in sorted(output_dir.iterdir())))
        finally:
            try:
                run(['security', 'list-keychains', '-d', 'user', '-s', *original])
            finally:
                if keychain.exists():
                    run(['security', 'delete-keychain', keychain])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--version', required=True)
    parser.add_argument('--arch', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    def interrupted(signum, _frame):
        raise SigningError(f'signing interrupted by signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    try:
        prepare(args.input, args.output, args.version, args.arch)
    except (SigningError, release.ReleaseError, OSError, ValueError, KeyError) as error:
        print(f'::error::{error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
