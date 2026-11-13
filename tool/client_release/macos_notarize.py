#!/usr/bin/env python3
"""Sign and notarize one verified same-run macOS build for direct distribution."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import signal
import stat
import shutil
import subprocess
import sys
import tempfile
import zipfile

import assemble_release as release

MACHO_MAGIC = {bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                             'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}
BUNDLES = {'.framework', '.app', '.xpc', '.appex', '.bundle', '.plugin'}
LEGACY_HELPER_SHA256 = '0a3d09438fb595802d554ce0a7c4ba8e1d2d91d5170362adc965da82e70d74cb'
HELPER_NAME = 'LaunchAtLoginHelper.app'


PHASES = frozenset({
    'dispatch', 'source-context', 'artifact-verification', 'credentials', 'keychain-create',
    'keychain-unlock', 'keychain-import', 'keychain-partition', 'keychain-search', 'identity-selection',
    'app-extraction', 'nested-signing', 'app-signing', 'app-notarization', 'app-stapling',
    'app-gatekeeper', 'dmg-creation', 'dmg-signing', 'dmg-notarization', 'dmg-stapling',
    'dmg-gatekeeper', 'output', 'keychain-cleanup',
})
current_phase = 'dispatch'


def phase(name):
    global current_phase
    if name not in PHASES:
        raise ValueError('unknown verification phase')
    current_phase = name
    print(f'::notice::macos-verification phase={name}', flush=True)


def safe_signing_error(error):
    message = str(error)
    allowed = {
        'version or architecture mismatch', 'same-run app archive missing',
        'output directory already exists', 'missing or invalid signing credentials',
        'could not capture the original keychain search list', 'invalid keychain input',
        'keychain operation failed', 'app archive has no ZolNit.app',
        'unexpected Core manifest: macOS helper hash binding requires review',
        'unexpected privileged Helper: embedded Core hash requires review',
        'bundled FlClashCore Mach-O is missing', 'app executable is missing',
        'invalid main app metadata', 'legacy helper path must not be a symlink',
        'legacy helper archive path must not be a symlink',
        'legacy helper archive missing or checksum mismatch', 'unsafe legacy helper archive',
        'invalid legacy helper archive', 'invalid legacy helper metadata or entitlements',
        'LaunchAtLogin resource directory must not be a symlink',
        'LaunchAtLogin build archive must not be a symlink',
        'LaunchAtLogin build archive must be a regular file',
        'MACOS_TEAM_ID must be a ten-character Apple team ID',
        'expected exactly one valid Developer ID Application identity for the team',
        'notarytool returned invalid JSON', 'final DMG is missing or empty',
        'MACOS_DEVELOPER_ID_P12_BASE64 missing or invalid base64',
        'APPLE_ASC_P8_BASE64 missing or invalid base64',
        'MACOS_DEVELOPER_ID_P12_BASE64 is empty', 'APPLE_ASC_P8_BASE64 is empty',
    }
    if message in allowed:
        return message
    if re.fullmatch(r'(?:security|codesign|ditto|hdiutil|spctl|xcrun (?:notarytool submit|stapler (?:staple|validate))) (?:timed out|failed with exit status [0-9]{1,3})', message):
        return message
    notary = re.fullmatch(r'(?:notary-app\.zip|ZolNit-[0-9.]+-macos-(?:arm64|x64)\.dmg) notarization not accepted: (Invalid|Rejected|In Progress|unknown)', message)
    if notary:
        return f'notarization not accepted: {notary.group(1)}'
    return 'details withheld'


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


def materialize_legacy_helper(app, scratch):
    try:
        main_info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        identifier = main_info['CFBundleIdentifier']
        minimum = main_info['LSMinimumSystemVersion']
        if not isinstance(identifier, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', identifier):
            raise ValueError('invalid identifier')
        if not isinstance(minimum, str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', minimum):
            raise ValueError('invalid minimum')
        version = tuple(int(x) for x in minimum.split('.'))
    except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException) as error:
        raise SigningError('invalid main app metadata') from error
    helper = app / 'Contents/Library/LoginItems' / HELPER_NAME
    for part in (app / 'Contents', app / 'Contents/Library', helper.parent, helper):
        if part.is_symlink():
            raise SigningError('legacy helper path must not be a symlink')
    resources = app / 'Contents/Resources/LaunchAtLogin_LaunchAtLogin.bundle/Contents/Resources'
    created = False
    if not helper.exists() and version < (13,):
        archive = resources / 'LaunchAtLoginHelper.zip'
        for part in (app / 'Contents/Resources', resources.parent.parent, resources.parent, resources, archive):
            if part.is_symlink():
                raise SigningError('legacy helper archive path must not be a symlink')
        if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest() != LEGACY_HELPER_SHA256:
            raise SigningError('legacy helper archive missing or checksum mismatch')
        try:
            with zipfile.ZipFile(archive) as source:
                members, seen, total = source.infolist(), set(), 0
                for item in members:
                    path = item.filename.rstrip('/')
                    parts = path.split('/')
                    mode = item.external_attr >> 16
                    if (not path or parts[0] != HELPER_NAME or any(part in ('', '.', '..') for part in parts)
                            or '\\' in path or path in seen or item.flag_bits & 1
                            or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)
                            or (item.is_dir() != (stat.S_IFMT(mode) == stat.S_IFDIR))):
                        raise SigningError('unsafe legacy helper archive')
                    seen.add(path)
                    total += item.file_size
                    if total > 16 * 1024 * 1024:
                        raise SigningError('unsafe legacy helper archive')
                helper.parent.mkdir(parents=True, exist_ok=True)
                for item in members:
                    destination = helper.parent.joinpath(*item.filename.rstrip('/').split('/'))
                    if item.is_dir():
                        destination.mkdir(parents=True, exist_ok=True)
                    else:
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        with source.open(item) as reader, destination.open('xb') as writer:
                            shutil.copyfileobj(reader, writer)
                        destination.chmod(0o755 if item.external_attr >> 16 & 0o111 else 0o644)
        except (OSError, zipfile.BadZipFile) as error:
            raise SigningError('invalid legacy helper archive') from error
        created = True
    if not helper.exists():
        return None, None
    info_path = helper / 'Contents/Info.plist'
    if any(path.is_symlink() for path in (helper / 'Contents', info_path, helper / 'Contents/MacOS')):
        raise SigningError('legacy helper path must not be a symlink')
    try:
        info = plistlib.loads(info_path.read_bytes())
        executable = info['CFBundleExecutable']
        if executable != 'LaunchAtLoginHelper' or info.get('CFBundlePackageType') != 'APPL':
            raise ValueError('invalid helper')
        binary = helper / 'Contents/MacOS' / executable
        if binary.is_symlink() or not binary.is_file() or binary.read_bytes()[:4] not in MACHO_MAGIC:
            raise ValueError('invalid helper executable')
        expected_id = identifier + '-LaunchAtLoginHelper'
        if created:
            info['CFBundleIdentifier'] = expected_id
            info_path.write_bytes(plistlib.dumps(info))
            entitlements = plistlib.loads((resources / 'LaunchAtLogin.entitlements').read_bytes())
            if not isinstance(entitlements, dict) or entitlements.get('com.apple.security.app-sandbox') is not True:
                raise ValueError('invalid helper entitlements')
        else:
            if info.get('CFBundleIdentifier') != expected_id:
                raise ValueError('wrong helper identifier')
            raw = run(['codesign', '-d', '--entitlements', ':-', helper])
            entitlements = plistlib.loads(raw.encode()) if raw.strip() else {}
            if not isinstance(entitlements, dict):
                raise ValueError('invalid helper entitlements')
        entitlements['com.apple.security.get-task-allow'] = False
        entitlement_path = scratch / 'legacy-helper-entitlements.plist'
        entitlement_path.write_bytes(plistlib.dumps(entitlements))
        entitlement_path.chmod(0o600)
        return helper, entitlement_path
    except (OSError, ValueError, KeyError, TypeError, plistlib.InvalidFileException) as error:
        raise SigningError('invalid legacy helper metadata or entitlements') from error


def remove_launch_at_login_build_archives(app):
    # SwiftPM bundles helper archives used by its build script, not by the runtime.
    resources = app
    for part in ('Contents', 'Resources', 'LaunchAtLogin_LaunchAtLogin.bundle', 'Contents', 'Resources'):
        resources = resources / part
        if resources.is_symlink():
            raise SigningError('LaunchAtLogin resource directory must not be a symlink')
    for name in ('LaunchAtLoginHelper.zip', 'LaunchAtLoginHelper-with-runtime.zip'):
        archive = resources / name
        if archive.is_symlink():
            raise SigningError('LaunchAtLogin build archive must not be a symlink')
        if archive.exists():
            if not archive.is_file():
                raise SigningError('LaunchAtLogin build archive must be a regular file')
            archive.unlink()


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
    phase('nested-signing')
    helper, helper_entitlements = materialize_legacy_helper(app, scratch)
    remove_launch_at_login_build_archives(app)
    for item in nested_code(app):
        command = ['codesign', '--force', '--sign', identity, '--options', 'runtime', '--timestamp']
        if item == helper:
            command.extend(['--entitlements', helper_entitlements])
        run([*command, item])
    phase('app-signing')
    run(['codesign', '--force', '--sign', identity, '--options', 'runtime', '--timestamp',
         '--entitlements', entitlements, app])
    run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', app])
    zipped = scratch / 'notary-app.zip'
    run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, zipped])
    phase('app-notarization')
    app_id = submit(zipped, key, key_id, issuer)
    phase('app-stapling')
    run(['xcrun', 'stapler', 'staple', app])
    run(['xcrun', 'stapler', 'validate', app])
    run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', app])
    phase('app-gatekeeper')
    run(['spctl', '--assess', '--type', 'execute', '--verbose=2', app])
    phase('dmg-creation')
    staging = scratch / 'dmg-content'
    staging.mkdir()
    run(['ditto', app, staging / 'ZolNit.app'])
    (staging / 'Applications').symlink_to('/Applications')
    run(['hdiutil', 'create', '-volname', 'ZolNit', '-srcfolder', staging, '-format', 'UDZO', dmg])
    phase('dmg-signing')
    run(['codesign', '--force', '--sign', identity, '--timestamp', dmg])
    run(['codesign', '--verify', '--strict', '--verbose=2', dmg])
    phase('dmg-notarization')
    dmg_id = submit(dmg, key, key_id, issuer)
    phase('dmg-stapling')
    run(['xcrun', 'stapler', 'staple', dmg])
    run(['xcrun', 'stapler', 'validate', dmg])
    run(['codesign', '--verify', '--strict', '--verbose=2', dmg])
    run(['hdiutil', 'verify', dmg])
    phase('dmg-gatekeeper')
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
    phase('credentials')
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
            phase('keychain-create')
            security_command('create-keychain', '-p', keychain_password, keychain)
            phase('keychain-unlock')
            security_command('unlock-keychain', '-p', keychain_password, keychain)
            phase('keychain-import')
            security_command('import', p12, '-k', keychain, '-P', password, '-T', '/usr/bin/codesign')
            phase('keychain-partition')
            security_command('set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', keychain_password, keychain)
            phase('keychain-search')
            run(['security', 'list-keychains', '-d', 'user', '-s', keychain, *original])
            phase('identity-selection')
            identity = select_identity(run(['security', 'find-identity', '-v', '-p', 'codesigning', keychain]), team)
            phase('app-extraction')
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
            phase('output')
            output_dir.mkdir(parents=True)
            shutil.copyfile(dmg, output_dir / dmg_name)
            (output_dir / 'signing-receipt.json').write_text(json.dumps(receipt, sort_keys=True) + '\n')
            (output_dir / 'SHA256SUMS').write_text(''.join(
                f'{release.sha256_file(p)}  {p.name}\n' for p in sorted(output_dir.iterdir())))
        finally:
            try:
                try:
                    run(['security', 'list-keychains', '-d', 'user', '-s', *original])
                finally:
                    if keychain.exists():
                        run(['security', 'delete-keychain', keychain])
            except Exception:
                phase('keychain-cleanup')
                raise


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
