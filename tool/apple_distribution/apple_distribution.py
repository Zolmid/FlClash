#!/usr/bin/env python3
"""Guarded local iOS archive export preparation.

The default operation is a read-only preflight and plan. Real export requires
--execute and explicit archive, profile, Team, and output paths.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Mapping, Optional, Sequence


DEFAULT_SOURCE_TAG = 'v1.1.4'
STABLE_TAG_RE = re.compile(r'^v(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})$')
COMMIT_SHA_RE = re.compile(r'^[0-9a-fA-F]{40}$')
TEAM_ID = '52QSDX4Y94'
APP_GROUP = 'group.com.zolmid.zolnit'
RENEWAL_KEYCHAIN_GROUP = f'{TEAM_ID}.com.zolmid.zolnit.renewal'
VALID_NATIVE_DISTRIBUTIONS = {'direct', 'apple-app-store'}
EXPECTED_NATIVE_DISTRIBUTION = {
    'release-testing': 'direct',
    'app-store-connect': 'apple-app-store',
}
NETWORK_EXTENSION = 'packet-tunnel-provider'
APPLE_ROOT_KEYCHAIN = '/System/Library/Keychains/SystemRootCertificates.keychain'
APPLE_PROVISIONING_SIGNER = 'Apple iPhone OS Provisioning Profile Signing'
TARGET_BUNDLE_IDS = {
    'app': 'com.zolmid.zolnit',
    'necore': 'com.zolmid.zolnit.NECore',
    'widget': 'com.zolmid.zolnit.Widget',
}
TARGET_APPEX_NAMES = {
    'necore': 'NECore.appex',
    'widget': 'Widget.appex',
}
CONTROL_CHARS = re.compile(r'[\x00-\x1f\x7f]')
HEX_SHA256 = re.compile(r'^[0-9a-fA-F]{64}$')
SYMBOL_FILE_RE = re.compile(r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.symbols$')
MAX_IPA_ENTRIES = 4096
MAX_IPA_MEMBER_BYTES = 512 * 1024 * 1024
MAX_IPA_TOTAL_BYTES = 1024 * 1024 * 1024


class ValidationError(ValueError):
    pass


@dataclass(frozen=True)
class Profile:
    target: str
    path: Path
    uuid: str
    team: str
    bundle_id: str
    app_group: str
    expires: datetime
    sha256: str


Runner = Callable[[Sequence[str]], subprocess.CompletedProcess[str]]


def safe_text(value: str, label: str) -> str:
    if not value or CONTROL_CHARS.search(value) or value.startswith('-'):
        raise ValidationError(f'invalid {label}')
    return value


def absolute_path(value: str, label: str) -> Path:
    safe_text(value, label)
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise ValidationError(f'{label} must be absolute')
    return path


def run_argv(argv: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(list(argv), check=True, text=True, capture_output=True)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def extract_plist_xml(raw: str) -> bytes:
    start = raw.find('<?xml')
    if start < 0:
        start = raw.find('<plist')
    end = raw.rfind('</plist>')
    if start < 0 or end < 0 or end < start:
        raise ValidationError('decoded CMS payload does not contain a valid plist XML document')
    return raw[start:end + len('</plist>')].encode('utf-8')


def verify_cms_profile(path: Path, runner: Runner) -> Mapping[str, object]:
    with tempfile.TemporaryDirectory(prefix='zolnit-cms-') as temp_name:
        temp_dir = Path(temp_name)
        root_pem = temp_dir / 'apple-root.pem'
        signer_pem = temp_dir / 'signer.pem'
        roots = runner(['security', 'find-certificate', '-a', '-c', 'Apple Root CA', '-p', APPLE_ROOT_KEYCHAIN])
        if roots.returncode != 0 or 'BEGIN CERTIFICATE' not in roots.stdout:
            raise ValidationError('Apple Root CA is unavailable for profile verification')
        root_pem.write_text(roots.stdout, encoding='utf-8')
        cmd = [
            'openssl', 'cms', '-verify', '-inform', 'DER', '-in', str(path),
            '-CAfile', str(root_pem), '-purpose', 'any', '-signer', str(signer_pem),
        ]
        if '-noverify' in cmd or '-nosigs' in cmd:
            raise ValidationError('unverified CMS decoding is forbidden')
        verified = runner(cmd)
        if verified.returncode != 0:
            raise ValidationError(f'CMS chain verification failed for {path}')
        cert_info = runner(['openssl', 'x509', '-in', str(signer_pem), '-noout', '-subject', '-issuer'])
        if cert_info.returncode != 0 or APPLE_PROVISIONING_SIGNER not in cert_info.stdout or 'Apple Inc.' not in cert_info.stdout:
            raise ValidationError(f'unexpected provisioning profile signer for {path}')
        return plistlib.loads(extract_plist_xml(verified.stdout))


def profile_plist(path: Path, runner: Runner, *, execute: bool = False) -> Mapping[str, object]:
    if path.suffix.lower() == '.plist':
        if execute:
            raise ValidationError('raw .plist profiles are rejected in --execute mode')
        with path.open('rb') as stream:
            return plistlib.load(stream)
    return verify_cms_profile(path, runner)


def _date(value: object) -> datetime:
    if not isinstance(value, datetime):
        raise ValidationError('profile ExpirationDate is missing or invalid')
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def validate_distribution_claims(
    target: str,
    distribution: str,
    payload: Mapping[str, object],
    entitlements: Mapping[str, object],
) -> None:
    if entitlements.get('get-task-allow') is not False:
        raise ValidationError(f'{target} profile must set get-task-allow to false')
    ne_values = entitlements.get('com.apple.developer.networking.networkextension')
    if not isinstance(ne_values, list) or NETWORK_EXTENSION not in ne_values:
        raise ValidationError(f'{target} profile missing {NETWORK_EXTENSION} entitlement')
    if target in {'app', 'necore'}:
        kc_groups = entitlements.get('keychain-access-groups')
        if not isinstance(kc_groups, list) or not any(
            g in {f'{TEAM_ID}.*', RENEWAL_KEYCHAIN_GROUP} or (
                isinstance(g, str) and g.startswith(f'{TEAM_ID}.') and g.endswith('*') and RENEWAL_KEYCHAIN_GROUP.startswith(g[:-1])
            )
            for g in kc_groups
        ):
            raise ValidationError(f'{target} profile keychain-access-groups does not authorize {RENEWAL_KEYCHAIN_GROUP}')
    provisions_all = bool(payload.get('ProvisionsAllDevices', False))
    if provisions_all:
        raise ValidationError(f'{target} profile cannot set ProvisionsAllDevices')
    devices = payload.get('ProvisionedDevices')
    beta_active = entitlements.get('beta-reports-active')
    if distribution == 'release-testing':
        if not isinstance(devices, list) or not devices or not all(isinstance(d, str) and d.strip() for d in devices):
            raise ValidationError(f'{target} Ad Hoc profile requires non-empty ProvisionedDevices')
        if beta_active is True:
            raise ValidationError(f'{target} Ad Hoc profile must not enable beta-reports-active')
    elif distribution == 'app-store-connect':
        if devices is not None:
            raise ValidationError(f'{target} App Store profile must not contain ProvisionedDevices')
        if target == 'app' and beta_active is not True:
            raise ValidationError('app profile for app-store-connect requires beta-reports-active=true')
    else:
        raise ValidationError('distribution must be release-testing or app-store-connect')


def read_profile(
    target: str,
    path: Path,
    expected_sha: Optional[str],
    runner: Runner,
    *,
    distribution: str = 'release-testing',
    execute: bool = False,
    require_trusted_hash: bool = False,
) -> Profile:
    if not path.is_file() or path.is_symlink():
        raise ValidationError(f'{target} profile must be a regular file')
    if execute and path.suffix.lower() == '.plist':
        raise ValidationError(f'{target} profile cannot be a raw .plist in --execute mode')
    if require_trusted_hash and not expected_sha:
        raise ValidationError(f'{target} profile requires an explicit --profile-sha256 in --execute mode')
    digest = sha256_file(path)
    if expected_sha and digest.lower() != expected_sha.lower():
        raise ValidationError(f'{target} profile SHA-256 mismatch')
    payload = profile_plist(path, runner, execute=execute)
    entitlements = payload.get('Entitlements')
    if not isinstance(entitlements, Mapping):
        raise ValidationError(f'{target} profile has no entitlements')
    application = str(entitlements.get('application-identifier', ''))
    bundle_id = application.split('.', 1)[-1] if '.' in application else ''
    expected_bundle = TARGET_BUNDLE_IDS[target]
    team_values = payload.get('TeamIdentifier')
    team = str(team_values[0]) if isinstance(team_values, list) and team_values else ''
    ent_team = str(entitlements.get('com.apple.developer.team-identifier', team))
    groups = entitlements.get('com.apple.security.application-groups', [])
    if bundle_id != expected_bundle:
        raise ValidationError(f'{target} profile Bundle ID mismatch')
    if team != TEAM_ID or ent_team != TEAM_ID or application != f'{TEAM_ID}.{expected_bundle}':
        raise ValidationError(f'{target} profile Team ID mismatch')
    if not isinstance(groups, list) or APP_GROUP not in groups:
        raise ValidationError(f'{target} profile App Group mismatch')
    validate_distribution_claims(target, distribution, payload, entitlements)
    now = datetime.now(timezone.utc)
    creation_raw = payload.get('CreationDate')
    if creation_raw is not None:
        created = _date(creation_raw)
        if created > now:
            raise ValidationError(f'{target} profile CreationDate is in the future')
    expires = _date(payload.get('ExpirationDate'))
    if expires <= now:
        raise ValidationError(f'{target} profile is expired')
    uuid = str(payload.get('UUID', ''))
    if not uuid or CONTROL_CHARS.search(uuid):
        raise ValidationError(f'{target} profile UUID is missing or invalid')
    return Profile(target, path, uuid, team, bundle_id, APP_GROUP, expires, digest)


def export_options(kind: str, profiles: Mapping[str, Profile]) -> dict[str, object]:
    if kind not in {'release-testing', 'app-store-connect'}:
        raise ValidationError('distribution must be release-testing or app-store-connect')
    method = 'release-testing' if kind == 'release-testing' else 'app-store-connect'
    return {
        'method': method,
        'signingStyle': 'manual',
        'teamID': TEAM_ID,
        'provisioningProfiles': {
            TARGET_BUNDLE_IDS[target]: profile.uuid for target, profile in profiles.items()
        },
    }


def embedded_profile_path(app_path: Path, target: str) -> Path:
    if target == 'app':
        return app_path / 'embedded.mobileprovision'
    appex = TARGET_APPEX_NAMES.get(target)
    if not appex:
        raise ValidationError(f'unknown target {target}')
    return app_path / 'PlugIns' / appex / 'embedded.mobileprovision'


def command_plan(
    archive: Path,
    options: Path,
    output: Path,
    *,
    upload_testflight: bool = False,
    ipa_path: Optional[Path] = None,
    asc_key_id: Optional[str] = None,
    asc_issuer_id: Optional[str] = None,
    asc_key_path: Optional[Path] = None,
) -> list[list[str]]:
    commands = [
        ['xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportOptionsPlist', str(options), '-exportPath', str(output)],
    ]
    if upload_testflight:
        if not asc_key_id or not asc_issuer_id:
            raise ValidationError('--upload-testflight requires --asc-api-key-id and --asc-api-issuer-id')
        if asc_key_path is not None and asc_key_path.name != f'AuthKey_{asc_key_id}.p8':
            raise ValidationError(f'ASC API key file must be named AuthKey_{asc_key_id}.p8 for API_PRIVATE_KEYS_DIR discovery')
        commands.append([
            'xcrun', 'altool', '--upload-app',
            '-f', str(ipa_path or (output / 'Runner.ipa')),
            '--type', 'ios',
            '--api-key', asc_key_id,
            '--api-issuer', asc_issuer_id,
        ])
    return commands


def verification_commands(app_path: Path, profiles: Mapping[str, Profile]) -> list[list[str]]:
    return [['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app_path)]]


def validate_bundle_renewal_info(bundle_dir: Path, expected_bundle_id: str, expected_native_dist: Optional[str] = None) -> str:
    info_path = bundle_dir / 'Info.plist'
    if not info_path.is_file() or info_path.is_symlink():
        raise ValidationError(f'missing Info.plist in {bundle_dir}')
    with info_path.open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('CFBundleIdentifier') != expected_bundle_id:
        raise ValidationError(f'CFBundleIdentifier mismatch in {bundle_dir}')
    kc_group = info.get('ZolNitRenewalKeychainAccessGroup')
    if kc_group != RENEWAL_KEYCHAIN_GROUP:
        raise ValidationError(f'{bundle_dir.name} Info.plist ZolNitRenewalKeychainAccessGroup must be {RENEWAL_KEYCHAIN_GROUP}, got {kc_group!r}')
    if info.get('ZolNitRenewalWhileLocked') is not True:
        raise ValidationError(f'{bundle_dir.name} Info.plist ZolNitRenewalWhileLocked must be true')
    native_dist = info.get('ZolNitDistribution')
    if native_dist not in VALID_NATIVE_DISTRIBUTIONS:
        raise ValidationError(f'{bundle_dir.name} Info.plist ZolNitDistribution must be in {sorted(VALID_NATIVE_DISTRIBUTIONS)}, got {native_dist!r}')
    if expected_native_dist is not None and native_dist != expected_native_dist:
        raise ValidationError(f'{bundle_dir.name} Info.plist ZolNitDistribution must be {expected_native_dist!r}, got {native_dist!r}')
    return str(native_dist)


def validate_app_renewal_contract(
    app_path: Path,
    runner: Runner,
    *,
    check_signed_entitlements: bool,
    distribution: Optional[str] = None,
) -> None:
    necore_path = app_path / 'PlugIns' / TARGET_APPEX_NAMES['necore']
    if not necore_path.is_dir() or necore_path.is_symlink():
        raise ValidationError('missing PlugIns/NECore.appex bundle')
    expected_native = EXPECTED_NATIVE_DISTRIBUTION.get(distribution) if distribution else None
    app_dist = validate_bundle_renewal_info(app_path, TARGET_BUNDLE_IDS['app'], expected_native)
    ne_dist = validate_bundle_renewal_info(necore_path, TARGET_BUNDLE_IDS['necore'], expected_native)
    if app_dist != ne_dist:
        raise ValidationError('Runner and NECore ZolNitDistribution values do not match')
    if check_signed_entitlements:
        for label, bundle_dir, expected_id in (
            ('app', app_path, TARGET_BUNDLE_IDS['app']),
            ('necore', necore_path, TARGET_BUNDLE_IDS['necore']),
        ):
            res = runner(['codesign', '-d', '--entitlements', ':-', str(bundle_dir)])
            if res.returncode != 0 or not res.stdout:
                raise ValidationError(f'failed to read signed entitlements from {label}')
            ent = plistlib.loads(extract_plist_xml(res.stdout))
            if ent.get('application-identifier') != f'{TEAM_ID}.{expected_id}':
                raise ValidationError(f'{label} signed application-identifier mismatch')
            if ent.get('com.apple.developer.team-identifier') != TEAM_ID:
                raise ValidationError(f'{label} signed team-identifier mismatch')
            groups = ent.get('com.apple.security.application-groups', [])
            if not isinstance(groups, list) or APP_GROUP not in groups:
                raise ValidationError(f'{label} signed entitlements missing {APP_GROUP}')
            ne_vals = ent.get('com.apple.developer.networking.networkextension', [])
            if not isinstance(ne_vals, list) or NETWORK_EXTENSION not in ne_vals:
                raise ValidationError(f'{label} signed entitlements missing {NETWORK_EXTENSION}')
            kc_groups = ent.get('keychain-access-groups', [])
            if not isinstance(kc_groups, list) or RENEWAL_KEYCHAIN_GROUP not in kc_groups:
                raise ValidationError(f'{label} signed entitlements missing {RENEWAL_KEYCHAIN_GROUP}')


def validate_archive_bundle(archive: Path, *, distribution: Optional[str] = None) -> None:
    if archive.is_symlink() or not archive.is_dir() or archive.suffix != '.xcarchive':
        raise ValidationError('archive path must be an existing .xcarchive directory')
    info_plist = archive / 'Info.plist'
    products_dir = archive / 'Products' / 'Applications'
    if not info_plist.is_file() or info_plist.is_symlink() or not products_dir.is_dir():
        raise ValidationError('archive path is not a valid Xcode archive bundle')
    apps = sorted(p for p in products_dir.glob('*.app') if p.is_dir() and not p.is_symlink())
    if len(apps) != 1:
        raise ValidationError('archive bundle must contain exactly one Products/Applications/*.app')
    validate_app_renewal_contract(
        apps[0],
        lambda _: subprocess.CompletedProcess([], 0, '', ''),
        check_signed_entitlements=False,
        distribution=distribution,
    )


def safe_extract_ipa(ipa_path: Path, temporary: Path) -> None:
    if ipa_path.is_symlink() or not ipa_path.is_file():
        raise ValidationError('IPA must be a regular file')
    with zipfile.ZipFile(ipa_path) as archive:
        members = archive.infolist()
        if not members or len(members) > MAX_IPA_ENTRIES:
            raise ValidationError('IPA entry count is invalid or exceeds limit')
        seen: set[str] = set()
        total_bytes = 0
        for member in members:
            if member.filename in seen:
                raise ValidationError(f'IPA contains duplicate entry {member.filename}')
            seen.add(member.filename)
            if '\\' in member.filename or member.filename.startswith('/'):
                raise ValidationError('IPA contains an unsafe archive path')
            member_path = Path(member.filename)
            parts = member_path.parts
            if member_path.is_absolute() or not parts or any(p in ('', '.', '..') for p in parts):
                raise ValidationError('IPA contains an unsafe archive path')
            top = parts[0]
            if top == 'Payload':
                pass
            elif top == 'Symbols':
                if len(parts) == 1:
                    if not member.is_dir():
                        raise ValidationError('IPA Symbols root must be a directory')
                elif len(parts) == 2 and not member.is_dir() and SYMBOL_FILE_RE.fullmatch(parts[1]):
                    pass
                else:
                    raise ValidationError(f'IPA contains an invalid Symbols entry {member.filename}')
            else:
                raise ValidationError('IPA contains an unsafe archive path')
            mode = (member.external_attr >> 16) & 0xFFFF
            file_type = stat.S_IFMT(mode)
            if file_type == stat.S_IFLNK:
                raise ValidationError('IPA contains a symbolic link entry')
            if file_type not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValidationError('IPA contains a non-regular file entry')
            if member.is_dir() and file_type not in (0, stat.S_IFDIR):
                raise ValidationError('IPA directory entry has non-directory mode')
            if not member.is_dir() and file_type == stat.S_IFDIR:
                raise ValidationError('IPA file entry has directory mode')
            if member.flag_bits & 0x1:
                raise ValidationError('IPA contains an encrypted entry')
            if member.file_size < 0 or member.file_size > MAX_IPA_MEMBER_BYTES:
                raise ValidationError('IPA entry exceeds size limit')
            total_bytes += member.file_size
            if total_bytes > MAX_IPA_TOTAL_BYTES:
                raise ValidationError('IPA total uncompressed size exceeds limit')
        for member in members:
            target_path = temporary / member.filename
            if member.is_dir():
                target_path.mkdir(parents=True, exist_ok=True)
                continue
            target_path.parent.mkdir(parents=True, exist_ok=True)
            mode = (member.external_attr >> 16) & 0xFFFF
            file_Dynamic_perm = 0o700 if (mode & 0o111) else 0o600
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0)
            fd = os.open(target_path, flags, file_Dynamic_perm)
            written = 0
            with archive.open(member) as src, os.fdopen(fd, 'wb') as dst:
                while True:
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    written += len(chunk)
                    if written > member.file_size:
                        raise ValidationError(f'IPA entry {member.filename} exceeds declared size')
                    dst.write(chunk)
                os.fchmod(dst.fileno(), file_Dynamic_perm)
            if written != member.file_size:
                raise ValidationError(f'IPA entry {member.filename} is truncated')


def exported_app(output: Path, temporary: Path) -> Path:
    direct_apps = sorted(p for p in output.glob('*.app') if p.is_dir() and not p.is_symlink())
    payload_apps = sorted(p for p in (output / 'Payload').glob('*.app') if p.is_dir() and not p.is_symlink()) if (output / 'Payload').is_dir() else []
    ipas = sorted(p for p in output.glob('*.ipa') if p.is_file() and not p.is_symlink())
    if ipas and (direct_apps or payload_apps):
        raise ValidationError('export directory contains both .ipa and unpacked .app bundles')
    if direct_apps or payload_apps:
        apps = direct_apps + payload_apps
        if len(apps) != 1:
            raise ValidationError(f'expected exactly one exported .app bundle, found {len(apps)}')
        return apps[0]
    if not ipas:
        raise ValidationError('export did not produce an app or IPA for verification')
    if len(ipas) != 1:
        raise ValidationError(f'expected exactly one exported IPA, found {len(ipas)}')
    safe_extract_ipa(ipas[0], temporary)
    payload_dir = temporary / 'Payload'
    apps = sorted(p for p in payload_dir.glob('*.app') if p.is_dir() and not p.is_symlink()) if payload_dir.is_dir() else []
    if len(apps) != 1:
        raise ValidationError(f'IPA must contain exactly one Payload/*.app bundle, found {len(apps)}')
    return apps[0]


def git_head(repo: Path, runner: Runner) -> str:
    return runner(['git', '-C', str(repo), 'rev-parse', 'HEAD']).stdout.strip()


def validate_source(repo: Path, source_sha: Optional[str], source_tag: Optional[str], runner: Runner) -> tuple[str, str]:
    tag = source_tag or DEFAULT_SOURCE_TAG
    safe_text(tag, 'source tag')
    if not STABLE_TAG_RE.fullmatch(tag):
        raise ValidationError(f'source tag {tag!r} must be a stable release tag vX.Y.Z')
    tag_ref = runner(['git', '-C', str(repo), 'rev-parse', '--verify', f'refs/tags/{tag}^{{commit}}'])
    if tag_ref.returncode != 0:
        raise ValidationError(f'stable tag {tag} does not exist in repository')
    resolved_sha = tag_ref.stdout.strip()
    if not COMMIT_SHA_RE.fullmatch(resolved_sha):
        raise ValidationError(f'stable tag {tag} did not resolve to a valid commit SHA')
    if source_sha is not None:
        safe_text(source_sha, 'source SHA')
        if not COMMIT_SHA_RE.fullmatch(source_sha):
            raise ValidationError('source SHA must be a 40-character hex commit SHA')
        if source_sha.lower() != resolved_sha.lower():
            raise ValidationError(f'source SHA {source_sha} does not match stable tag {tag} ({resolved_sha})')
    head_sha = git_head(repo, runner)
    if head_sha.lower() != resolved_sha.lower():
        raise ValidationError(f'worktree HEAD {head_sha} does not match stable tag {tag} ({resolved_sha})')
    return tag, resolved_sha


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--repo', default=str(Path(__file__).resolve().parents[3]))
    parser.add_argument('--source-sha')
    parser.add_argument('--source-tag', default=DEFAULT_SOURCE_TAG)
    parser.add_argument('--distribution', choices=['release-testing', 'app-store-connect'], default='release-testing')
    parser.add_argument('--team-id')
    parser.add_argument('--app-profile')
    parser.add_argument('--necore-profile')
    parser.add_argument('--widget-profile')
    parser.add_argument('--profile-sha256', action='append', default=[])
    parser.add_argument('--archive-path')
    parser.add_argument('--export-path')
    parser.add_argument('--export-options-path')
    parser.add_argument('--prepare-source', action='store_true')
    parser.add_argument('--signing-identity')
    parser.add_argument('--signing-keychain')
    parser.add_argument('--upload-testflight', action='store_true')
    parser.add_argument('--asc-api-key-id')
    parser.add_argument('--asc-api-issuer-id')
    parser.add_argument('--asc-api-key-path')
    return parser.parse_args(argv)


def parse_hashes(values: Sequence[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for value in values:
        if '=' not in value:
            raise ValidationError('profile hash must be TARGET=SHA256')
        target, digest = value.split('=', 1)
        if target not in TARGET_BUNDLE_IDS or not HEX_SHA256.fullmatch(digest):
            raise ValidationError('invalid profile hash')
        result[target] = digest.lower()
    return result


def main(argv: Sequence[str] | None = None, runner: Runner = run_argv) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        repo = absolute_path(args.repo, 'repo')
        if args.execute and not args.team_id:
            raise ValidationError('--execute requires --team-id')
        if args.team_id and args.team_id != TEAM_ID:
            raise ValidationError('Team ID mismatch')
        if args.upload_testflight and args.distribution != 'app-store-connect':
            raise ValidationError('--upload-testflight is only valid with --distribution app-store-connect')
        asc_key_id = safe_text(args.asc_api_key_id, 'ASC API key ID') if args.asc_api_key_id else None
        asc_issuer_id = safe_text(args.asc_api_issuer_id, 'ASC API issuer ID') if args.asc_api_issuer_id else None
        asc_key_path = absolute_path(args.asc_api_key_path, 'ASC API key path') if args.asc_api_key_path else None
        if args.upload_testflight and args.execute:
            if not asc_key_id or not asc_issuer_id or not asc_key_path:
                raise ValidationError('--upload-testflight requires --asc-api-key-id, --asc-api-issuer-id, and --asc-api-key-path')
            if not asc_key_path.is_file() or asc_key_path.is_symlink():
                raise ValidationError('ASC API key path must be a regular file')
        resolved_tag, resolved_sha = validate_source(repo, args.source_sha, args.source_tag, runner)
        if args.prepare_source:
            from source_preparation import prepare_ios_source_tree
            prepared = prepare_ios_source_tree(repo, args.distribution)
            if not args.app_profile and not args.necore_profile and not args.widget_profile and not args.execute:
                print(json.dumps({'mode': 'prepare-source', 'source_tag': resolved_tag, 'source_sha': resolved_sha, **prepared}, indent=2))
                return 0
        paths = {
            'app': absolute_path(args.app_profile, 'app profile') if args.app_profile else None,
            'necore': absolute_path(args.necore_profile, 'NECore profile') if args.necore_profile else None,
            'widget': absolute_path(args.widget_profile, 'Widget profile') if args.widget_profile else None,
        }
        if any(path is None for path in paths.values()):
            raise ValidationError('all three provisioning profiles are required')
        hashes = parse_hashes(args.profile_sha256)
        profiles = {
            target: read_profile(
                target,
                path,
                hashes.get(target),
                runner,
                distribution=args.distribution,
                execute=args.execute,
                require_trusted_hash=args.execute,
            )
            for target, path in paths.items()
            if path
        }
        options = export_options(args.distribution, profiles)
        if not args.execute:
            planned_commands = command_plan(
                Path(args.archive_path or '<archive>'),
                Path('<ExportOptions.plist>'),
                Path(args.export_path or '<export>'),
                upload_testflight=args.upload_testflight,
                asc_key_id=asc_key_id or '<asc-key-id>',
                asc_issuer_id=asc_issuer_id or '<asc-issuer-id>',
                asc_key_path=asc_key_path or Path('<asc-key-path>'),
            )
            print(json.dumps({
                'mode': 'preflight',
                'distribution': args.distribution,
                'source_tag': resolved_tag,
                'source_sha': resolved_sha,
                'targets': list(profiles),
                'commands': planned_commands,
            }, indent=2))
            return 0
        if not args.archive_path or not args.export_path:
            raise ValidationError('--execute requires --archive-path and --export-path')
        archive = absolute_path(args.archive_path, 'archive path')
        output = absolute_path(args.export_path, 'export path')
        validate_archive_bundle(archive, distribution=args.distribution)
        archive_app = archive / 'Products' / 'Applications' / 'Runner.app'
        signing_identity = safe_text(args.signing_identity, 'signing identity') if args.signing_identity else None
        signing_keychain = absolute_path(args.signing_keychain, 'signing keychain') if args.signing_keychain else None
        if signing_identity:
            from source_preparation import sign_archive_bundle
            sign_archive_bundle(archive, args.distribution, profiles, signing_identity, runner, keychain_path=signing_keychain)
        else:
            if not (archive_app / '_CodeSignature').is_dir() or not (archive_app / 'embedded.mobileprovision').is_file():
                raise ValidationError('archive is unsigned; pass --signing-identity (and optional --signing-keychain) or pre-sign before --execute')
        output.mkdir(parents=True, exist_ok=True)
        remove_options = not args.export_options_path
        if args.export_options_path:
            options_path = absolute_path(args.export_options_path, 'ExportOptions path')
            options_path.parent.mkdir(parents=True, exist_ok=True)
            with options_path.open('wb') as stream:
                os.chmod(options_path, 0o600)
                plistlib.dump(options, stream)
        else:
            with tempfile.NamedTemporaryFile(prefix='zolnit-export-', suffix='.plist', dir=repo, delete=False) as stream:
                os.chmod(stream.name, 0o600)
                plistlib.dump(options, stream)
                options_path = Path(stream.name)
        try:
            for command in command_plan(archive, options_path, output, upload_testflight=False):
                runner(command)
            with tempfile.TemporaryDirectory(prefix='zolnit-verify-') as temporary_name:
                app_path = exported_app(output, Path(temporary_name))
                for command in verification_commands(app_path, profiles):
                    runner(command)
                validate_app_renewal_contract(app_path, runner, check_signed_entitlements=True, distribution=args.distribution)
                for target, expected in profiles.items():
                    embedded = embedded_profile_path(app_path, target)
                    actual = read_profile(
                        target,
                        embedded,
                        expected.sha256,
                        runner,
                        distribution=args.distribution,
                        execute=True,
                        require_trusted_hash=True,
                    )
                    if actual.uuid != expected.uuid:
                        raise ValidationError(f'{target} embedded profile UUID mismatch')
            if args.upload_testflight:
                ipas = sorted(p for p in output.glob('*.ipa') if p.is_file() and not p.is_symlink())
                if len(ipas) != 1:
                    raise ValidationError('TestFlight upload requires exactly one exported IPA')
                upload_cmds = command_plan(
                    archive,
                    options_path,
                    output,
                    upload_testflight=True,
                    ipa_path=ipas[0],
                    asc_key_id=asc_key_id,
                    asc_issuer_id=asc_issuer_id,
                    asc_key_path=asc_key_path,
                )
                runner(upload_cmds[-1])
            print(json.dumps({
                'mode': 'execute',
                'distribution': args.distribution,
                'source_tag': resolved_tag,
                'source_sha': resolved_sha,
                'targets': list(profiles),
                'commands': command_plan(
                    archive,
                    options_path,
                    output,
                    upload_testflight=args.upload_testflight,
                    asc_key_id=asc_key_id,
                    asc_issuer_id=asc_issuer_id,
                    asc_key_path=asc_key_path,
                ),
            }, indent=2))
        finally:
            if remove_options:
                options_path.unlink(missing_ok=True)
        return 0
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException, ValidationError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
