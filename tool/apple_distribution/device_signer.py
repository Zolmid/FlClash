#!/usr/bin/env python3
"""Opt-in Apple device signer: publish one stable unsigned archive, or sign one queued Ad Hoc device job.

Every mode refuses to run unless ZOLNIT_APPLE_DEVICE_SIGNING_ENABLED=true.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

from apple_distribution import (
    TARGET_BUNDLE_IDS,
    TEAM_ID,
    ValidationError,
    command_plan,
    embedded_profile_path,
    export_options,
    exported_app,
    read_profile,
    run_argv,
    validate_app_renewal_contract,
    validate_archive_bundle,
    verification_commands,
)
from archive_packer import PackError, pack_archive, release_identity, validate_archive_release
from device_job import extract_verified_archive, file_digest
from device_provisioning import AppleAPI, ProvisioningError, apple_jwt, ensure_device, ensure_profile
from signer_config import GitHubOIDC, load_config, verify_signing_identity
from signer_config import ConfigError
from signer_runtime import CancellableRunner, LeaseKeeper, LeaseLost
from signing_transport import MAX_BYTES, SIGNED_TTL, SigningTransport, TransportError, expected_archive_key
from source_preparation import sign_archive_bundle

ENABLE_ENV = 'ZOLNIT_APPLE_DEVICE_SIGNING_ENABLED'
MIN_ARTIFACT_LIFETIME = 3600
PROFILE_UUID_RE = re.compile(r'^[A-Za-z0-9-]{1,64}$')
CLIENT_ERROR = re.compile(r'^signing_http_4[0-9]{2}$')
ERROR_CODE_RE = re.compile(r'^[a-z0-9_:-]{1,64}$')
TRANSIENT_APPLE = re.compile(r'^apple_api_(unavailable|http_(401|403|408|429|5[0-9]{2}))$')
RECEIPT_KEYS = {'schema_version', 'tag', 'source_sha', 'build', 'core_sha', 'archive_zip', 'archive_key',
                'archive_sha256', 'archive_size'}
DISTRIBUTION = 'release-testing'


def profile_install_dirs(home: Path) -> list:
    return [home / 'Library' / 'MobileDevice' / 'Provisioning Profiles',
            home / 'Library' / 'Developer' / 'Xcode' / 'UserData' / 'Provisioning Profiles']


@contextmanager
def installed_profiles(profiles, directories):
    """Expose per-device profiles to xcodebuild only for the export, then remove exactly the copies made here."""
    created = []
    try:
        for directory in directories:
            directory.mkdir(parents=True, exist_ok=True, mode=0o700)
            for profile in profiles.values():
                if not PROFILE_UUID_RE.fullmatch(profile.uuid):
                    raise ValidationError('profile UUID is invalid')
                target = directory / (profile.uuid + '.mobileprovision')
                if target.is_symlink() or target.exists():
                    if target.is_symlink() or not target.is_file() or file_digest(target) != profile.sha256:
                        raise ValidationError('conflicting installed provisioning profile')
                    continue
                data = profile.path.read_bytes()
                if hashlib.sha256(data).hexdigest() != profile.sha256:
                    raise ValidationError('provisioning profile changed before install')
                fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
                created.append(target)
                with os.fdopen(fd, 'wb') as stream:
                    stream.write(data)
        yield
    finally:
        for target in created:
            target.unlink(missing_ok=True)


def export_direct(archive: Path, profiles, identity: str, keychain: Path, export_dir: Path, runner, install_dirs) -> Path:
    """Sign the extracted archive copy with per-device profiles, export Ad Hoc, and verify the exported IPA."""
    if set(profiles) != set(TARGET_BUNDLE_IDS):
        raise ValidationError('all three device profiles are required')
    validate_archive_bundle(archive, distribution=DISTRIBUTION)
    sign_archive_bundle(archive, DISTRIBUTION, profiles, identity, runner, keychain_path=keychain)
    export_dir.mkdir(mode=0o700)
    options = export_options(DISTRIBUTION, profiles)
    options['signingCertificate'] = identity
    options_path = export_dir.parent / 'ExportOptions.plist'
    fd = os.open(options_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(fd, 'wb') as stream:
        plistlib.dump(options, stream)
    try:
        with installed_profiles(profiles, install_dirs):
            for command in command_plan(archive, options_path, export_dir):
                runner(command)
    finally:
        options_path.unlink(missing_ok=True)
    ipas = sorted(export_dir.glob('*.ipa'))
    if len(ipas) != 1 or ipas[0].is_symlink() or not ipas[0].is_file():
        raise ValidationError('direct export must produce exactly one IPA')
    verify_dir = export_dir.parent / 'export-verify'
    verify_dir.mkdir(mode=0o700)
    try:
        app = exported_app(export_dir, verify_dir)
        for command in verification_commands(app, profiles):
            runner(command)
        validate_app_renewal_contract(app, runner, check_signed_entitlements=True, distribution=DISTRIBUTION)
        for target, expected in profiles.items():
            actual = read_profile(target, embedded_profile_path(app, target), expected.sha256, runner,
                                  distribution=DISTRIBUTION, execute=True, require_trusted_hash=True)
            if actual.uuid != expected.uuid:
                raise ValidationError(target + ' embedded profile UUID mismatch')
    finally:
        shutil.rmtree(verify_dir, ignore_errors=True)
    return ipas[0]


def provision_with_apple(api, config, job, directory: Path, runner):
    device = job['device']
    resource = ensure_device(api, device)
    profiles = {target: ensure_profile(api, target, config['bundle_resource_ids'][target], config['certificate_resource_id'],
                                       resource, device['device_id'], job['release']['build'], device['udid'],
                                       config['certificate_sha256'], directory, runner)
                for target in TARGET_BUNDLE_IDS}
    return resource, profiles


def artifact_expiry(profiles, now: float) -> int:
    expires = min([int(now) + SIGNED_TTL] + [int(p.expires.timestamp()) for p in profiles.values()])
    if expires <= int(now) + MIN_ARTIFACT_LIFETIME:
        raise ProvisioningError('artifact_expiry_too_short')
    return expires


def completion_payload(job: dict, ready: dict) -> dict:
    release = job['release']
    return {'job_id': job['job_id'], 'lease_token': job['lease_token'], 'outcome': 'ready',
            'team_id': TEAM_ID, 'bundle_id': TARGET_BUNDLE_IDS['app'], 'release_tag': release['tag'],
            'source_sha': release['source_sha'], 'archive_sha256': release['archive_sha256'],
            'artifact_key': ready['artifact_key'], 'artifact_sha256': ready['artifact_sha256'],
            'artifact_size': ready['artifact_size'], 'artifact_expires_at': ready['artifact_expires_at'],
            'apple_device_resource_id': ready['apple_device_resource_id']}


def failure_payload(job: dict, error_code: str) -> dict:
    return {'job_id': job['job_id'], 'lease_token': job['lease_token'], 'outcome': 'failed',
            'error_code': error_code, 'retryable': False}


def permanent_error_code(error, phase='export'):
    """Stable code for errors that retrying the same job cannot fix; None leaves the job to lease expiry."""
    if isinstance(error, (LeaseLost, TransportError, ConfigError)):
        return None
    if isinstance(error, subprocess.CalledProcessError):
        return phase + '_command_failed'
    if isinstance(error, ValidationError):
        return phase + '_validation_failed'
    if isinstance(error, ProvisioningError):
        code = str(error)
        if TRANSIENT_APPLE.fullmatch(code):
            return None
        return code if ERROR_CODE_RE.fullmatch(code) else 'signer_provisioning_failed'
    return None


def _complete(transport, keeper, build_payload, attempts, sleep):
    for attempt in range(attempts):
        keeper.check()
        try:
            return transport.complete_job(build_payload(keeper.snapshot()))
        except LeaseLost:
            raise
        except TransportError as error:
            if CLIENT_ERROR.fullmatch(str(error)) or attempt + 1 == attempts:
                raise
        sleep(min(2 ** attempt, 10))
    raise TransportError('signing_completion_unavailable')


def _report_failure(transport, keeper, code, attempts, sleep):
    try:
        keeper.check()
        _complete(transport, keeper, lambda job: failure_payload(job, code), attempts, sleep)
    except ProvisioningError:
        pass


def sign_one(transport, provision, export, workdir: Path, *, now=time.time, keeper_factory=None,
             runner_factory=CancellableRunner, complete_attempts=3, sleep=time.sleep) -> dict:
    job = transport.claim_job()
    if job is None:
        return {'state': 'idle'}
    keeper = (keeper_factory or (lambda t, j: LeaseKeeper(t, j, now=now)))(transport, job)
    keeper.start()
    upload_started = False
    phase = 'archive'
    try:
        stored = transport.signed_status(keeper.snapshot())
        reused = stored is not None
        if stored is None:
            try:
                runner = runner_factory(keeper)
                release = job['release']
                downloaded = transport.download_archive(release, workdir / 'archive.zip')
                keeper.check()
                archive = extract_verified_archive(downloaded, workdir / 'archive', release)
                validate_archive_release(archive, release['tag'], release['build'])
                keeper.check()
                phase = 'profile'
                device_resource, profiles = provision(keeper.snapshot(), workdir / 'profiles', runner)
                expires = artifact_expiry(profiles, now())
                phase = 'export'
                ipa = export(archive, profiles, workdir / 'export', runner)
                keeper.check()
                if ipa.is_symlink() or not ipa.is_file() or not 1024 <= ipa.stat().st_size <= MAX_BYTES:
                    raise ProvisioningError('exported_artifact_invalid')
                digest, size = file_digest(ipa), ipa.stat().st_size
                keeper.renew()
            except Exception as error:
                code = permanent_error_code(error, phase)
                if code is not None:
                    _report_failure(transport, keeper, code, complete_attempts, sleep)
                raise
            upload_started = True
            uploaded = transport.upload_signed(keeper.snapshot(), ipa, digest, size, expires,
                                               apple_device_resource_id=device_resource)
            if uploaded.get('artifact_key') != job['expected_artifact_key'] or uploaded.get('sha256') != digest or uploaded.get('size') != size or uploaded.get('expires_at') != expires:
                raise ProvisioningError('stored_artifact_attestation_mismatch')
            stored = {'artifact_key': uploaded['artifact_key'], 'artifact_sha256': digest, 'artifact_size': size,
                      'artifact_expires_at': expires, 'apple_device_resource_id': device_resource}
        result = _complete(transport, keeper, lambda current: completion_payload(current, stored), complete_attempts, sleep)
        return {'state': result['status'], 'job_id': job['job_id'], 'reused': reused, 'uploaded': upload_started}
    finally:
        keeper.stop()


def _write_private_json(path: Path, value: dict) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(fd, 'w', encoding='utf-8') as stream:
        json.dump(value, stream, sort_keys=True)


def archive_prepare(source: Path, tag: str, core_sha: str, archive: Path, output: Path, receipt_path: Path, runner=run_argv) -> dict:
    identity = release_identity(source, tag, core_sha, runner)
    validate_archive_release(archive, identity['tag'], identity['build'])
    packed = pack_archive(archive, output)
    try:
        with tempfile.TemporaryDirectory(prefix='zolnit-pack-verify-') as temp:
            extracted = extract_verified_archive(output, Path(temp) / 'archive', packed)
            validate_archive_release(extracted, identity['tag'], identity['build'])
            if any(extracted.rglob('_CodeSignature')) or any(extracted.rglob('*.mobileprovision')):
                raise PackError('archive_signing_material_present')
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    receipt = {'schema_version': 1, **identity, 'archive_zip': str(output), 'archive_key': expected_archive_key(identity['tag']),
               'archive_sha256': packed['archive_sha256'], 'archive_size': packed['archive_size']}
    _write_private_json(receipt_path, receipt)
    return receipt


def read_receipt(path: Path) -> dict:
    fd = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    with os.fdopen(fd, 'rb') as stream:
        if os.fstat(stream.fileno()).st_mode & 0o077:
            raise PackError('archive_receipt_permissions_invalid')
        receipt = json.loads(stream.read(65536))
    if not isinstance(receipt, dict) or set(receipt) != RECEIPT_KEYS or receipt['schema_version'] != 1:
        raise PackError('archive_receipt_invalid')
    zip_path = Path(receipt['archive_zip'])
    if (not zip_path.is_absolute() or zip_path.is_symlink() or not zip_path.is_file()
            or zip_path.stat().st_size != receipt['archive_size'] or file_digest(zip_path) != receipt['archive_sha256']):
        raise PackError('archive_receipt_digest_mismatch')
    if receipt['archive_key'] != expected_archive_key(receipt['tag']):
        raise PackError('archive_receipt_key_mismatch')
    return receipt


def archive_publish(receipt_path: Path, transport) -> dict:
    receipt = read_receipt(receipt_path)
    stored = transport.upload_archive(Path(receipt['archive_zip']), receipt['tag'], receipt['source_sha'], receipt['build'])
    if stored.get('archive_key') != receipt['archive_key'] or stored.get('archive_sha256') != receipt['archive_sha256'] or stored.get('archive_size') != receipt['archive_size']:
        raise TransportError('upload_attestation_mismatch')
    return transport.register_archive(receipt['tag'], receipt['source_sha'], receipt['build'], stored)


def archive_resume(source: Path, tag: str, core_sha: str, transport, runner=run_argv) -> dict:
    """Register an archive the edge already holds for this exact source instead of rebuilding a new binary."""
    identity = release_identity(source, tag, core_sha, runner)
    existing = transport.archive_status(identity['tag'], identity['source_sha'], identity['build'])
    if existing is None:
        return {'prepared': False, **identity}
    data = transport.register_archive(identity['tag'], identity['source_sha'], identity['build'], existing)
    return {'prepared': True, **identity, 'archive_key': data['archive_key'],
            'archive_sha256': data['archive_sha256'], 'archive_size': data['archive_size']}


def run_sign_one(args, env) -> dict:
    config = load_config(Path(args.config))
    verify_signing_identity(config, run_argv)
    transport = SigningTransport(GitHubOIDC(env))
    api = AppleAPI(lambda: apple_jwt(config['api_key_path'], config['api_key_id'], config['api_issuer_id']))
    root = Path(args.workdir_root)
    if not root.is_absolute() or not root.is_dir():
        raise ValidationError('workdir root must be an existing absolute directory')
    workdir = Path(tempfile.mkdtemp(prefix='zolnit-device-sign-', dir=root))
    try:
        return sign_one(
            transport,
            lambda job, directory, runner: provision_with_apple(api, config, job, directory, runner),
            lambda archive, profiles, directory, runner: export_direct(
                archive, profiles, config['signing_identity'], config['signing_keychain'], directory, runner,
                profile_install_dirs(Path.home())),
            workdir)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    prepare = modes.add_parser('archive-prepare', help='validate source and archive, then pack a deterministic zip')
    prepare.add_argument('--source-dir', required=True)
    prepare.add_argument('--source-tag', required=True)
    prepare.add_argument('--core-sha', required=True)
    prepare.add_argument('--archive-path', required=True)
    prepare.add_argument('--output-zip', required=True)
    prepare.add_argument('--receipt', required=True)
    publish = modes.add_parser('archive-publish', help='upload the packed archive and register it archive-ready')
    publish.add_argument('--receipt', required=True)
    resume = modes.add_parser('archive-resume', help='before building, register an already uploaded archive for this exact source')
    resume.add_argument('--source-dir', required=True)
    resume.add_argument('--source-tag', required=True)
    resume.add_argument('--core-sha', required=True)
    resume.add_argument('--github-output')
    sign = modes.add_parser('sign-one', help='claim and process at most one queued device job')
    sign.add_argument('--config', required=True)
    sign.add_argument('--workdir-root', required=True)
    return parser.parse_args(argv)


def main(argv=None, environ=None) -> int:
    env = os.environ if environ is None else environ
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if env.get(ENABLE_ENV) != 'true':
        print('ERROR: apple_device_signer_disabled', file=sys.stderr)
        return 3
    try:
        if args.mode == 'archive-prepare':
            receipt = archive_prepare(Path(args.source_dir), args.source_tag, args.core_sha, Path(args.archive_path),
                                      Path(args.output_zip), Path(args.receipt))
            print(json.dumps({'mode': args.mode, **{k: receipt[k] for k in ['tag', 'source_sha', 'build', 'core_sha', 'archive_key', 'archive_sha256', 'archive_size']}}))
        elif args.mode == 'archive-publish':
            data = archive_publish(Path(args.receipt), SigningTransport(GitHubOIDC(env)))
            print(json.dumps({'mode': args.mode, 'state': data['state'], 'archive_key': data['archive_key'], 'archive_sha256': data['archive_sha256']}))
        elif args.mode == 'archive-resume':
            result = archive_resume(Path(args.source_dir), args.source_tag, args.core_sha, SigningTransport(GitHubOIDC(env)))
            if args.github_output:
                with open(args.github_output, 'a', encoding='utf-8') as output:
                    output.write('prepared=' + ('true' if result['prepared'] else 'false') + '\n')
            print(json.dumps({'mode': args.mode, **result}))
        else:
            result = run_sign_one(args, env)
            print(json.dumps({'mode': args.mode, **result}))
            if result['state'] not in ['idle', 'ready', 'cancelled', 'superseded']:
                return 2
        return 0
    except subprocess.CalledProcessError as error:
        print('ERROR: command_failed ' + Path(str(error.cmd[0])).name + ' ' + str(error.returncode), file=sys.stderr)
    except (ProvisioningError, ValidationError, OSError, ValueError, KeyError) as error:
        print('ERROR: ' + type(error).__name__ + ' ' + str(error), file=sys.stderr)
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
