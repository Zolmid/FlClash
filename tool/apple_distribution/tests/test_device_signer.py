import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock
import urllib.error
from datetime import datetime, timedelta, timezone
import zipfile

from apple_distribution import APP_GROUP, NETWORK_EXTENSION, RENEWAL_KEYCHAIN_GROUP, TARGET_BUNDLE_IDS, TEAM_ID, ValidationError, read_profile
from archive_packer import PackError, pack_archive, release_identity, validate_archive_release
from device_job import extract_verified_archive
from device_provisioning import ProvisioningError
import device_signer
from device_signer import archive_prepare, artifact_expiry, export_direct, sign_one
from signer_config import AUDIENCE, ISSUER, ConfigError, GitHubOIDC, load_config, verify_signing_identity
from signer_runtime import CancellableRunner, LeaseKeeper, LeaseLost
from signing_transport import ORIGIN, SigningTransport, TransportError
from source_preparation import projected_target_entitlements
from test_signing_transport import Opener, Response

TAG, BUILD, SOURCE, CORE = 'v1.1.4', 2026110805, 'd' * 40, '8380d0e7462f061a964323e9bf3129a236fcc5d5'
UDID = '00008110-0011223344556677'


def make_archive(root: Path, version='1.1.4', build=BUILD) -> Path:
    archive = root / 'Runner.xcarchive'
    app = archive / 'Products' / 'Applications' / 'Runner.app'
    bundles = {'app': app, 'necore': app / 'PlugIns' / 'NECore.appex', 'widget': app / 'PlugIns' / 'Widget.appex'}
    for target, path in bundles.items():
        path.mkdir(parents=True)
        info = {'CFBundleIdentifier': TARGET_BUNDLE_IDS[target], 'CFBundleShortVersionString': version,
                'CFBundleVersion': str(build), 'ZolNitDistribution': 'direct',
                'ZolNitRenewalKeychainAccessGroup': RENEWAL_KEYCHAIN_GROUP, 'ZolNitRenewalWhileLocked': True}
        with (path / 'Info.plist').open('wb') as stream:
            plistlib.dump(info, stream)
    framework = app / 'Frameworks' / 'Flutter.framework'
    (framework / '_CodeSignature').mkdir(parents=True)
    (framework / '_CodeSignature' / 'CodeResources').write_bytes(b'sig')
    binary = framework / 'Flutter'
    binary.write_bytes(os.urandom(4096))
    binary.chmod(0o755)
    (framework / 'Resources').mkdir()
    (framework / 'Resources' / 'icudtl.dat').write_bytes(b'r' * 2048)
    (framework / 'Current').symlink_to('Resources')
    (framework / 'Data').symlink_to('Resources/icudtl.dat')
    (app / 'embedded.mobileprovision').write_bytes(b'stale profile')
    with (archive / 'Info.plist').open('wb') as stream:
        plistlib.dump({'ArchiveVersion': 2, 'Name': 'Runner'}, stream)
    return archive


def fake_jwt(**claims) -> str:
    def part(value):
        return base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b'=').decode()
    return part({'alg': 'RS256'}) + '.' + part(claims) + '.' + 'sig'


def signer_job(release, now):
    return {'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'lease_expires_at': int(now) + 300,
            'team_id': TEAM_ID, 'bundle_id': TARGET_BUNDLE_IDS['app'],
            'device': {'device_id': 'c' * 32, 'udid': UDID},
            'extensions': [TARGET_BUNDLE_IDS['necore'], TARGET_BUNDLE_IDS['widget']],
            'release': release, 'expected_artifact_key': 'apple-adhoc/signed/v1.1.4/' + 'a' * 32 + '.ipa'}


class FakeTransport:
    def __init__(self, job, now=time.time):
        self.job, self.now = job, now
        self.calls = []
        self.stored = None
        self.complete_failures = 0
        self.renew_error = None
        self.archive_zip = None
        self.payloads = []
        self.upload_error = None

    def claim_job(self):
        self.calls.append('claim')
        return json.loads(json.dumps(self.job))

    def renew_job(self, job):
        self.calls.append('renew')
        if self.renew_error:
            raise TransportError(self.renew_error)
        return {'job_id': job['job_id'], 'status': 'leased', 'lease_expires_at': int(self.now()) + 300}

    def signed_status(self, job):
        self.calls.append('status')
        return dict(self.stored) if self.stored else None

    def download_archive(self, release, destination):
        self.calls.append('download')
        destination.write_bytes(self.archive_zip.read_bytes())
        return destination

    def upload_signed(self, job, path, digest, size, expires_at, apple_device_resource_id=None):
        self.calls.append('upload')
        if self.upload_error:
            raise TransportError(self.upload_error)
        self.upload_args = {'expires_at': expires_at, 'resource': apple_device_resource_id, 'lease': job['lease_expires_at']}
        self.stored = {'artifact_key': job['expected_artifact_key'], 'artifact_sha256': digest, 'artifact_size': size,
                       'artifact_expires_at': expires_at, 'apple_device_resource_id': apple_device_resource_id}
        return {'artifact_key': job['expected_artifact_key'], 'sha256': digest, 'size': size, 'expires_at': expires_at}

    def complete_job(self, payload):
        self.calls.append('complete')
        self.completed = payload
        self.payloads.append(dict(payload))
        if self.complete_failures:
            self.complete_failures -= 1
            raise TransportError('signing_transport_unavailable')
        return {'job_id': payload['job_id'], 'status': 'ready' if payload['outcome'] == 'ready' else 'failed'}


class Profile:
    def __init__(self, days):
        self.expires = datetime.now(timezone.utc) + timedelta(days=days)


class ResumeTransport:
    def __init__(self, status, error):
        self.status, self.error, self.registered = status, error, []

    def archive_status(self, tag, source_sha, build):
        if self.error:
            raise self.error
        return dict(self.status) if self.status else None

    def register_archive(self, tag, source_sha, build, stored):
        self.registered.append((tag, source_sha, build, stored))
        return {**stored, 'state': 'ready'}


class PackerTests(unittest.TestCase):
    def test_pack_is_deterministic_strips_signing_and_round_trips_through_extractor(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = make_archive(root)
            first = pack_archive(archive, root / 'one.zip')
            second = pack_archive(archive, root / 'two.zip')
            self.assertEqual((root / 'one.zip').read_bytes(), (root / 'two.zip').read_bytes())
            self.assertEqual(stat.S_IMODE((root / 'one.zip').stat().st_mode), 0o600)
            names = zipfile.ZipFile(root / 'one.zip').namelist()
            self.assertFalse([n for n in names if '_CodeSignature' in n or n.endswith('.mobileprovision')])
            extracted = extract_verified_archive(root / 'one.zip', root / 'out', first)
            framework = extracted / 'Products/Applications/Runner.app/Frameworks/Flutter.framework'
            self.assertTrue((framework / 'Flutter').stat().st_mode & 0o111)
            self.assertFalse((framework / 'Current').is_symlink())
            self.assertEqual((framework / 'Current' / 'icudtl.dat').read_bytes(), b'r' * 2048)
            self.assertEqual((framework / 'Data').read_bytes(), b'r' * 2048)
            validate_archive_release(extracted, TAG, BUILD)
            self.assertEqual(first['archive_sha256'], second['archive_sha256'])

    def test_unsafe_links_special_files_and_key_material_are_rejected(self):
        cases = {
            'archive_symlink_absolute': lambda a, r: (a / 'abs').symlink_to('/etc/hosts'),
            'archive_symlink_escape': lambda a, r: (a / 'esc').symlink_to('../outside.txt'),
            'archive_symlink_dangling': lambda a, r: (a / 'gone').symlink_to('missing'),
            'archive_symlink_cycle': lambda a, r: (a / 'Products' / 'loop').symlink_to('..'),
            'archive_special_file': lambda a, r: os.mkfifo(a / 'fifo'),
            'archive_contains_private_key_material': lambda a, r: (a / 'dist.p12').write_bytes(b'k'),
        }
        for reason, mutate in cases.items():
            with self.subTest(reason), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                (root / 'outside.txt').write_text('secret')
                archive = make_archive(root)
                mutate(archive, root)
                with self.assertRaises(PackError) as caught:
                    pack_archive(archive, root / 'out.zip')
                self.assertEqual(str(caught.exception), reason)
                self.assertFalse((root / 'out.zip').exists())

    def test_release_identity_binds_tag_build_and_core_gitlink(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp)
            (source / 'pubspec.yaml').write_text('name: x\nversion: 1.1.4+2026110805\n')
            core = [CORE]

            def runner(argv):
                if argv[-1].startswith('refs/tags/') or argv[-1] == 'HEAD' and argv[2] == str(source):
                    return subprocess.CompletedProcess(argv, 0, SOURCE + '\n', '')
                return subprocess.CompletedProcess(argv, 0, core[0] + '\n', '')
            self.assertEqual(release_identity(source, TAG, CORE, runner),
                             {'tag': TAG, 'source_sha': SOURCE, 'build': BUILD, 'core_sha': CORE})
            core[0] = 'f' * 40
            with self.assertRaises(PackError):
                release_identity(source, TAG, CORE, runner)
            core[0] = CORE
            (source / 'pubspec.yaml').write_text('version: 1.1.5+7\n')
            with self.assertRaises(PackError):
                release_identity(source, TAG, CORE, runner)

    def test_archive_version_must_match_release(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = make_archive(Path(temp), build=7)
            with self.assertRaises(PackError):
                validate_archive_release(archive, TAG, BUILD)


class OIDCTests(unittest.TestCase):
    URL = 'https://pipelines.actions.githubusercontent.com/abc/idtoken?api-version=2.0'

    def env(self, url=URL):
        return {'ACTIONS_ID_TOKEN_REQUEST_URL': url, 'ACTIONS_ID_TOKEN_REQUEST_TOKEN': 'request-secret'}

    def test_fixed_audience_header_auth_and_safe_expiry_refresh(self):
        clock = [1000]
        opener = Opener(lambda r: Response(r, {'value': fake_jwt(aud=AUDIENCE, iss=ISSUER, exp=clock[0] + 600, iat=clock[0])}))
        opener.open = lambda request, timeout: (opener.requests.append(request), opener.callback(request))[1]
        oidc = GitHubOIDC(self.env(), opener, now=lambda: clock[0])
        oidc()
        oidc()
        self.assertEqual(oidc.fetches, 1)
        request = opener.requests[0]
        self.assertTrue(request.full_url.endswith('api-version=2.0&audience=zolnit-apple-device-signer'))
        self.assertNotIn('request-secret', request.full_url)
        self.assertEqual(request.get_header('Authorization'), 'Bearer request-secret')
        clock[0] += 500
        oidc()
        self.assertEqual(oidc.fetches, 2)

    def test_endpoint_redirect_and_claim_validation(self):
        for url in ['http://pipelines.actions.githubusercontent.com/x', 'https://evil.example.com/x',
                    'https://actions.githubusercontent.com.evil.com/x', 'https://u@pipelines.actions.githubusercontent.com/x',
                    self.URL + '&audience=other']:
            with self.assertRaises(ConfigError):
                GitHubOIDC(self.env(url), Opener(lambda r: None))
        redirected = Opener(lambda r: Response(r, {'value': 'x'}, url='https://evil.example.com/token'))
        redirected.open = lambda request, timeout: redirected.callback(request)
        with self.assertRaisesRegex(ConfigError, 'oidc_redirect_rejected'):
            GitHubOIDC(self.env(), redirected, now=lambda: 1000)()
        for claims, reason in [({'aud': 'other', 'iss': ISSUER, 'exp': 1600}, 'oidc_audience_mismatch'),
                               ({'aud': AUDIENCE, 'iss': 'https://evil', 'exp': 1600}, 'oidc_issuer_mismatch'),
                               ({'aud': AUDIENCE, 'iss': ISSUER, 'exp': 1010}, 'oidc_token_expiry_invalid')]:
            opener = Opener(lambda r, c=claims: Response(r, {'value': fake_jwt(**c)}))
            opener.open = lambda request, timeout, o=opener: o.callback(request)
            with self.assertRaisesRegex(ConfigError, reason):
                GitHubOIDC(self.env(), opener, now=lambda: 1000)()


class ConfigTests(unittest.TestCase):
    def write(self, root: Path, mode=0o600, **changes):
        key = root / 'AuthKey.p8'
        key.write_text('synthetic')
        key.chmod(0o600)
        keychain = root / 'signing.keychain-db'
        keychain.write_bytes(b'')
        data = {'schema_version': 1, 'team_id': TEAM_ID, 'api_key_path': str(key), 'api_key_id': 'ABCDEFGHIJ',
                'api_issuer_id': '11111111-2222-3333-4444-555555555555', 'signing_keychain': str(keychain),
                'signing_identity': 'A' * 40, 'certificate_resource_id': 'CERT1', 'certificate_sha256': 'e' * 64,
                'bundle_resource_ids': {'app': 'B1', 'necore': 'B2', 'widget': 'B3'}}
        data.update(changes)
        path = root / 'config.json'
        path.write_text(json.dumps(data))
        path.chmod(mode)
        return path

    def test_restricted_config_and_identity_certificate_binding(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = load_config(self.write(root))
            self.assertEqual(config['bundle_resource_ids']['widget'], 'B3')
            der = b'synthetic certificate'
            identity = hashlib.sha1(der).hexdigest().upper()
            config.update(signing_identity=identity, certificate_sha256=hashlib.sha256(der).hexdigest())
            pem = '-----BEGIN CERTIFICATE-----\n' + base64.b64encode(der).decode() + '\n-----END CERTIFICATE-----\n'

            def runner(argv):
                return subprocess.CompletedProcess(argv, 0, ('  1) ' + identity + ' "Apple Distribution"') if 'find-identity' in argv else pem, '')
            verify_signing_identity(config, runner)
            config['certificate_sha256'] = 'f' * 64
            with self.assertRaisesRegex(ConfigError, 'signing_certificate_mismatch'):
                verify_signing_identity(config, runner)
        for mode, changes in [(0o644, {}), (0o600, {'udid': UDID}), (0o600, {'bundle_resource_ids': {'app': 'B1', 'necore': 'B1', 'widget': 'B3'}})]:
            with tempfile.TemporaryDirectory() as temp, self.assertRaises(ConfigError):
                load_config(self.write(Path(temp), mode, **changes))


class LeaseTests(unittest.TestCase):
    def test_heartbeat_renews_every_interval_and_extends_deadline(self):
        clock = [1000.0]
        transport = FakeTransport(None, now=lambda: clock[0])
        keeper = LeaseKeeper(transport, {'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'lease_expires_at': 1300}, now=lambda: clock[0])
        self.assertEqual(keeper.tick(), 60)
        self.assertEqual(transport.calls, [])
        clock[0] = 1060
        keeper.tick()
        self.assertEqual((transport.calls, keeper.snapshot()['lease_expires_at']), (['renew'], 1360))
        transport.renew_error = 'signing_transport_unavailable'
        clock[0] = 1120
        self.assertEqual(keeper.tick(), 10)
        self.assertFalse(keeper.lost)
        transport.renew_error = 'signing_http_409'
        clock[0] = 1130
        self.assertIsNone(keeper.tick())
        with self.assertRaisesRegex(LeaseLost, 'signing_lease_lost'):
            keeper.check()

    def test_hard_duration_is_enforced_even_when_renewals_succeed(self):
        clock = [0.0]
        transport = FakeTransport(None, now=lambda: clock[0])
        keeper = LeaseKeeper(transport, {'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'lease_expires_at': 300}, now=lambda: clock[0])
        while clock[0] < 1799:
            clock[0] += 60
            if keeper.tick() is None:
                break
        self.assertEqual(keeper.reason, 'signing_max_duration_exceeded')
        self.assertGreaterEqual(clock[0], 1800)
        self.assertEqual(transport.calls.count('renew'), 29)

    def test_lost_lease_kills_running_export_process_group(self):
        transport = FakeTransport(None)
        transport.renew_error = 'signing_http_410'
        keeper = LeaseKeeper(transport, {'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'lease_expires_at': time.time() + 300}, interval=0.1)
        runner = CancellableRunner(keeper, poll=0.05, grace=2)
        keeper.start()
        started = time.time()
        try:
            with self.assertRaises(LeaseLost):
                runner([sys.executable, '-c', 'import time; time.sleep(30)'])
        finally:
            keeper.stop()
        self.assertLess(time.time() - started, 10)
        with self.assertRaises(ProcessLookupError):
            os.kill(runner.last_pid, 0)


class SignOneTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / 'src').mkdir()
        packed = pack_archive(make_archive(self.root / 'src'), self.root / 'archive.zip')
        release = {'tag': TAG, 'source_sha': SOURCE, 'build': BUILD,
                   'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip', **packed}
        release.pop('entries')
        self.transport = FakeTransport(signer_job(release, time.time()))
        self.transport.archive_zip = self.root / 'archive.zip'
        self.counts = {'provision': 0, 'export': 0}

    def tearDown(self):
        self.temp.cleanup()

    def provision(self, job, directory, runner):
        self.counts['provision'] += 1
        self.assertNotIn(UDID, json.dumps(directory.parts))
        return 'DEVICE-RES-1', {'app': Profile(30), 'necore': Profile(3), 'widget': Profile(30)}

    def export(self, archive, profiles, directory, runner):
        self.counts['export'] += 1
        validate_archive_release(archive, TAG, BUILD)
        directory.mkdir()
        ipa = directory / 'Runner.ipa'
        ipa.write_bytes(b'i' * 4096)
        return ipa

    def run_once(self, workdir, **kwargs):
        workdir.mkdir(mode=0o700)
        return sign_one(self.transport, self.provision, self.export, workdir, sleep=lambda _: None, **kwargs)

    def test_expiry_is_identical_for_upload_and_completion_and_bounded_by_profiles(self):
        result = self.run_once(self.root / 'w1')
        self.assertEqual(result['state'], 'ready')
        expires = self.transport.upload_args['expires_at']
        self.assertEqual(self.transport.completed['artifact_expires_at'], expires)
        self.assertAlmostEqual(expires, time.time() + 3 * 86400, delta=5)
        self.assertEqual(self.transport.completed['apple_device_resource_id'], 'DEVICE-RES-1')
        self.assertEqual(self.transport.upload_args['resource'], 'DEVICE-RES-1')
        self.assertLess(self.transport.calls.index('renew'), self.transport.calls.index('upload'))
        with self.assertRaises(ProvisioningError):
            artifact_expiry({'app': Profile(0)}, time.time())

    def test_completion_retry_reuses_stored_artifact_without_apple_export_or_upload(self):
        self.transport.complete_failures = 3
        with self.assertRaises(TransportError):
            self.run_once(self.root / 'w1')
        self.assertEqual(self.transport.calls.count('complete'), 3)
        self.assertEqual({p['outcome'] for p in self.transport.payloads}, {'ready'})
        self.assertEqual((self.counts, self.transport.calls.count('upload')), ({'provision': 1, 'export': 1}, 1))
        first = dict(self.transport.completed)
        self.transport.calls.clear()
        result = self.run_once(self.root / 'w2')
        self.assertEqual((result['state'], result['reused']), ('ready', True))
        self.assertEqual(self.transport.calls, ['claim', 'status', 'complete'])
        self.assertEqual(self.counts, {'provision': 1, 'export': 1})
        self.assertEqual(self.transport.completed, first)

    def test_lease_lost_during_export_never_uploads_or_completes(self):
        def export(archive, profiles, directory, runner):
            self.transport.renew_error = 'signing_http_409'
            runner([sys.executable, '-c', 'import time; time.sleep(30)'])
        self.export = export
        factory = lambda t, j: LeaseKeeper(t, j, interval=0.1)
        with self.assertRaises(LeaseLost):
            self.run_once(self.root / 'w1', keeper_factory=factory,
                          runner_factory=lambda k: CancellableRunner(k, poll=0.05, grace=2))
        self.assertNotIn('upload', self.transport.calls)
        self.assertNotIn('complete', self.transport.calls)

    def test_permanent_errors_report_failed_once_with_sanitized_code(self):
        def bad_device(job, directory, runner):
            raise ProvisioningErrorType('device_disabled_or_wrong_platform')

        def bad_profile(job, directory, runner):
            raise ValidationError('widget profile CreationDate is in the future')

        def bad_export(archive, profiles, directory, runner):
            raise ValidationError('widget profile SHA-256 mismatch at ' + str(directory) + ' ' + UDID)
        for name, provision, export, code in [
                ('device', bad_device, self.export, 'device_disabled_or_wrong_platform'),
                ('profile', bad_profile, self.export, 'profile_validation_failed'),
                ('export', self.provision, bad_export, 'export_validation_failed')]:
            with self.subTest(name):
                self.transport.payloads.clear()
                self.transport.calls.clear()
                self.provision, self.export = provision, export
                with self.assertRaises(Exception):
                    self.run_once(self.root / ('w-' + name))
                self.assertEqual(self.transport.payloads, [{'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'outcome': 'failed',
                                                            'error_code': code, 'retryable': False}])
                self.assertNotIn('upload', self.transport.calls)
                self.assertNotIn(UDID, json.dumps(self.transport.payloads))

    def test_transient_lost_lease_and_post_upload_errors_never_report_failure(self):
        def apple_down(job, directory, runner):
            raise ProvisioningErrorType('apple_api_http_503')
        self.provision = apple_down
        with self.assertRaises(ProvisioningErrorType):
            self.run_once(self.root / 'w1')
        self.assertEqual(self.transport.payloads, [])

        clock = [time.time()]

        def expired_then_invalid(job, directory, runner):
            clock[0] += 3600
            raise ProvisioningErrorType('profile_state_invalid')
        self.provision = expired_then_invalid
        with self.assertRaises(ProvisioningErrorType):
            self.run_once(self.root / 'w2', keeper_factory=lambda t, j: LeaseKeeper(t, j, now=lambda: clock[0]))
        self.assertEqual(self.transport.payloads, [])

        self.provision = SignOneTests.provision.__get__(self)
        self.transport.upload_error = 'upload_attestation_mismatch'
        with self.assertRaises(TransportError):
            self.run_once(self.root / 'w3')
        self.assertEqual(self.transport.payloads, [])


ProvisioningErrorType = ProvisioningError


class StrictEdge:
    """Mirrors the Worker multipart checks: part order, sizes, final flag, lease header, and X-Content-Sha256."""

    PART = 8 * 1024 * 1024

    def __init__(self, test, lease=None):
        self.test, self.lease, self.session, self.parts = test, lease, None, {}

    def __call__(self, request):
        path = request.full_url.removeprefix(ORIGIN)
        if path.endswith('/authorize'):
            return Response(request, {'data': {'lease': 's' * 43, 'expires_at': 10 ** 10}})
        if path.endswith('/sessions'):
            self.session = json.loads(request.data)
            return Response(request, {'id': '11111111-1111-4111-8111-111111111111', 'state': 'uploading', 'max_part_bytes': self.PART})
        if '/parts/' in path:
            number, data = int(path.rsplit('/', 1)[1]), request.data
            size = self.session.get('artifact_size', self.session.get('archive_size'))
            offset = (number - 1) * self.PART
            final = request.get_header('X-final-part') == 'true'
            self.test.assertEqual(len(data), min(self.PART, size - offset))
            self.test.assertEqual(final, offset + len(data) == size)
            self.test.assertEqual(request.get_header('X-content-sha256'), hashlib.sha256(data).hexdigest())
            self.test.assertEqual(request.get_header('X-signing-lease'), self.lease)
            self.test.assertNotIn(number, self.parts)
            self.parts[number] = data
            return Response(request, b'', 204)
        if path.endswith('/complete'):
            blob = b''.join(self.parts[n] for n in sorted(self.parts))
            session = self.session
            if 'artifact_size' in session:
                return Response(request, {'state': 'ready', 'artifact_key': session['expected_artifact_key'],
                                          'artifact_sha256': hashlib.sha256(blob).hexdigest(), 'artifact_size': len(blob),
                                          'artifact_expires_at': session['artifact_expires_at']})
            return Response(request, {'state': 'ready', 'archive_key': session['archive_key'],
                                      'archive_sha256': hashlib.sha256(blob).hexdigest(), 'archive_size': len(blob)})
        self.test.fail('unexpected path ' + path)


class ExportDirectTests(unittest.TestCase):
    def payload(self, target):
        now = datetime.now(timezone.utc)
        return {'UUID': target.upper() + '-0000-UUID', 'TeamIdentifier': [TEAM_ID], 'CreationDate': now - timedelta(days=1),
                'ExpirationDate': now + timedelta(days=30), 'ProvisionedDevices': [UDID],
                'Entitlements': {'application-identifier': TEAM_ID + '.' + TARGET_BUNDLE_IDS[target],
                                 'com.apple.developer.team-identifier': TEAM_ID,
                                 'com.apple.security.application-groups': [APP_GROUP],
                                 'com.apple.developer.networking.networkextension': [NETWORK_EXTENSION],
                                 'keychain-access-groups': [TEAM_ID + '.*'], 'get-task-allow': False}}

    def runner_for(self, root, installs, tamper=None):
        calls = []

        def runner(argv):
            calls.append(argv)
            if argv[:2] == ['security', 'find-certificate']:
                return subprocess.CompletedProcess(argv, 0, '-----BEGIN CERTIFICATE-----', '')
            if argv[:3] == ['openssl', 'cms', '-verify']:
                return subprocess.CompletedProcess(argv, 0, Path(argv[argv.index('-in') + 1]).read_text(), '')
            if argv[:2] == ['openssl', 'x509']:
                return subprocess.CompletedProcess(argv, 0, 'subject=Apple iPhone OS Provisioning Profile Signing, O=Apple Inc.', '')
            if argv[:3] == ['codesign', '-d', '--entitlements']:
                target = 'necore' if argv[-1].endswith('NECore.appex') else 'app'
                return subprocess.CompletedProcess(argv, 0, plistlib.dumps(projected_target_entitlements(target, 'release-testing')).decode(), '')
            if argv[:2] == ['xcodebuild', '-exportArchive']:
                options = plistlib.loads(Path(argv[argv.index('-exportOptionsPlist') + 1]).read_bytes())
                self.assertEqual((options['method'], options['signingStyle']), ('release-testing', 'manual'))
                self.assertTrue(all(any(d.glob('*.mobileprovision')) for d in installs))
                app = Path(argv[argv.index('-archivePath') + 1]) / 'Products/Applications/Runner.app'
                with zipfile.ZipFile(Path(argv[argv.index('-exportPath') + 1]) / 'Runner.ipa', 'w') as ipa:
                    for file in sorted(app.rglob('*')):
                        if file.is_file():
                            data = file.read_bytes()
                            if tamper and file.name == 'embedded.mobileprovision' and 'Widget' in str(file):
                                data = tamper
                            ipa.writestr('Payload/' + str(file.relative_to(app.parent)), data)
            return subprocess.CompletedProcess(argv, 0, '', '')
        return runner, calls

    def test_direct_export_installs_temporarily_and_verifies_embedded_profiles(self):
        for tamper in [None, b'tampered']:
            with self.subTest(tamper=bool(tamper)), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                archive = make_archive(root)
                installs = [root / 'home' / 'mobiledevice', root / 'home' / 'xcode']
                runner, calls = self.runner_for(root, installs, tamper)
                profiles = {}
                (root / 'profiles').mkdir()
                for target in TARGET_BUNDLE_IDS:
                    path = root / 'profiles' / (target + '.mobileprovision')
                    path.write_bytes(plistlib.dumps(self.payload(target)))
                    profiles[target] = read_profile(target, path, hashlib.sha256(path.read_bytes()).hexdigest(), runner,
                                                    distribution='release-testing', execute=True, require_trusted_hash=True)
                (root / 'job').mkdir()
                if tamper:
                    with self.assertRaisesRegex(ValidationError, 'widget profile SHA-256 mismatch'):
                        export_direct(archive, profiles, 'A' * 40, root / 'kc', root / 'job' / 'export', runner, installs)
                else:
                    ipa = export_direct(archive, profiles, 'A' * 40, root / 'kc', root / 'job' / 'export', runner, installs)
                    self.assertEqual(ipa.name, 'Runner.ipa')
                    self.assertTrue(any(c[:2] == ['codesign', '--verify'] for c in calls))
                self.assertEqual([p for d in installs for p in d.glob('*')], [])
                self.assertFalse((root / 'job' / 'ExportOptions.plist').exists())


class TransportRecoveryTests(unittest.TestCase):
    def head(self, status=200, **headers):
        values = {'X-Archive-Tag': TAG, 'X-Source-Sha': SOURCE, 'X-Archive-Sha256': 'e' * 64, 'Content-Length': '2048'}
        values.update(headers)
        requests = []

        def handle(request):
            requests.append(request)
            if status != 200:
                raise urllib.error.HTTPError(request.full_url, status, 'x', {}, None)
            return Response(request, b'', headers={k: v for k, v in values.items() if v is not None})
        client = SigningTransport(lambda: 'oidc-token', Opener(handle), now=lambda: 1000)
        return client, requests

    def test_archive_status_head_contract(self):
        client, requests = self.head()
        self.assertEqual(client.archive_status(TAG, SOURCE, BUILD), {
            'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip',
            'archive_sha256': 'e' * 64, 'archive_size': 2048})
        request = requests[0]
        self.assertEqual((request.get_method(), request.full_url), ('HEAD', ORIGIN + '/__release/v1/apple/archives/' + TAG))
        self.assertEqual(request.get_header('Authorization'), 'Bearer oidc-token')
        client, _ = self.head(404)
        self.assertIsNone(client.archive_status(TAG, SOURCE, BUILD))

    def test_archive_status_fails_closed_on_wrong_metadata_or_other_http(self):
        bad = [{'X-Archive-Tag': 'v1.1.3'}, {'X-Source-Sha': 'a' * 40}, {'X-Archive-Sha256': 'E' * 64},
               {'X-Archive-Sha256': None}, {'Content-Length': '100'}, {'Content-Length': None}, {'Content-Length': '01024'}]
        for headers in bad:
            with self.subTest(headers=headers):
                client, _ = self.head(**headers)
                with self.assertRaisesRegex(TransportError, 'archive_status_mismatch'):
                    client.archive_status(TAG, SOURCE, BUILD)
        for status in [403, 409, 410, 500, 503]:
            with self.subTest(status=status):
                client, _ = self.head(status)
                with self.assertRaisesRegex(TransportError, 'signing_http_' + str(status)):
                    client.archive_status(TAG, SOURCE, BUILD)
        redirected = Opener(lambda r: Response(r, b'', url='https://evil.example.com/x'))
        with self.assertRaisesRegex(TransportError, 'signing_redirect_rejected'):
            SigningTransport(lambda: 'oidc', redirected, now=lambda: 1000).archive_status(TAG, SOURCE, BUILD)

    def test_archive_resume_registers_existing_ready_without_building(self):
        ready = {'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip', 'archive_sha256': 'e' * 64, 'archive_size': 2048}
        identity = {'tag': TAG, 'source_sha': SOURCE, 'build': BUILD, 'core_sha': CORE}
        for status, expected in [(ready, True), (None, False)]:
            transport = ResumeTransport(status, None)
            with mock.patch.object(device_signer, 'release_identity', return_value=dict(identity)) as identity_check:
                result = device_signer.archive_resume(Path('/src'), TAG, CORE, transport)
            identity_check.assert_called_once()
            self.assertEqual(result['prepared'], expected)
            self.assertEqual(transport.registered, [(TAG, SOURCE, BUILD, ready)] if expected else [])
        for error in [TransportError('archive_status_mismatch'), TransportError('signing_http_503')]:
            transport = ResumeTransport(None, error)
            with mock.patch.object(device_signer, 'release_identity', return_value=dict(identity)), self.assertRaises(TransportError):
                device_signer.archive_resume(Path('/src'), TAG, CORE, transport)
            self.assertEqual(transport.registered, [])
        transport = ResumeTransport(ready, None)
        with mock.patch.object(device_signer, 'release_identity', side_effect=PackError('source_core_mismatch')), self.assertRaises(PackError):
            device_signer.archive_resume(Path('/src'), TAG, CORE, transport)
        self.assertEqual(transport.registered, [])

    def test_multipart_signed_upload_satisfies_worker_part_contract(self):
        job = self.job()
        now = 1000
        edge = StrictEdge(self, job['lease_token'])
        client = SigningTransport(lambda: 'oidc', Opener(edge), now=lambda: now)
        content = os.urandom(StrictEdge.PART + 5000)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'Runner.ipa'
            path.write_bytes(content)
            result = client.upload_signed(job, path, hashlib.sha256(content).hexdigest(), len(content), now + 86400,
                                          apple_device_resource_id='DEV1')
        self.assertEqual(sorted(edge.parts), [1, 2])
        self.assertEqual(edge.session['apple_device_resource_id'], 'DEV1')
        self.assertEqual(result['expires_at'], now + 86400)
        with self.assertRaises(TransportError), tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'Runner.ipa'
            path.write_bytes(content)
            client.upload_signed(job, path, hashlib.sha256(content).hexdigest(), len(content), now + 86400,
                                 apple_device_resource_id='X' * 65)

    def test_archive_upload_parts_carry_content_digest(self):
        edge = StrictEdge(self)
        client = SigningTransport(lambda: 'oidc', Opener(edge), now=lambda: 1000)
        content = os.urandom(4096)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'archive.zip'
            path.write_bytes(content)
            client.upload_archive(path, TAG, SOURCE, BUILD)
        self.assertEqual(edge.parts[1], content)

    def job(self):
        return signer_job({'tag': TAG, 'source_sha': SOURCE, 'build': BUILD, 'archive_size': 2048, 'archive_sha256': 'e' * 64,
                           'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip'}, 1000)

    def test_signed_status_sends_lease_headers_and_validates_ready_metadata(self):
        job = self.job()
        ready = {'state': 'ready', 'job_id': job['job_id'], 'release_tag': TAG, 'source_sha': SOURCE, 'archive_sha256': 'e' * 64,
                 'artifact_key': job['expected_artifact_key'], 'artifact_sha256': 'f' * 64, 'artifact_size': 4096,
                 'artifact_expires_at': 1000 + 86400, 'apple_device_resource_id': 'DEV1'}
        replies = [{'state': 'missing'}, ready, {**ready, 'source_sha': 'a' * 40}]
        opener = Opener(lambda r: Response(r, replies.pop(0)))
        client = SigningTransport(lambda: 'oidc', opener, now=lambda: 1000)
        self.assertIsNone(client.signed_status(job))
        request = opener.requests[0]
        self.assertEqual(request.full_url, ORIGIN + '/__release/v1/apple/signed/status/' + job['job_id'])
        self.assertEqual((request.get_method(), request.get_header('X-signing-lease'), request.get_header('X-expected-artifact-key')),
                         ('GET', job['lease_token'], job['expected_artifact_key']))
        self.assertEqual(client.signed_status(job)['apple_device_resource_id'], 'DEV1')
        with self.assertRaisesRegex(TransportError, 'signed_status_mismatch'):
            client.signed_status(job)

    def test_archive_ready_registration_payload_and_reply(self):
        stored = {'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip', 'archive_sha256': 'e' * 64, 'archive_size': 2048}
        sent = []

        def handle(request):
            body = json.loads(request.data)
            sent.append(body)
            reply = {k: v for k, v in body.items() if k != 'schema_version'}
            return Response(request, {'data': {**reply, 'state': 'ready' if len(sent) == 1 else 'pending'}})
        client = SigningTransport(lambda: 'oidc', Opener(handle), now=lambda: 1000)
        client.register_archive(TAG, SOURCE, BUILD, stored)
        self.assertEqual(sent[0], {'schema_version': 1, 'tag': TAG, 'source_sha': SOURCE, 'build': BUILD, **stored,
                                   'extensions': ['com.zolmid.zolnit.NECore', 'com.zolmid.zolnit.Widget']})
        with self.assertRaisesRegex(TransportError, 'archive_registration_mismatch'):
            client.register_archive(TAG, SOURCE, BUILD, stored)


class CliTests(unittest.TestCase):
    def test_archive_resume_cli_writes_plain_boolean_only_after_success(self):
        identity = {'tag': TAG, 'source_sha': SOURCE, 'build': BUILD, 'core_sha': CORE}
        ready = {'archive_key': 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip', 'archive_sha256': 'e' * 64, 'archive_size': 2048}
        cases = [(ready, None, 0, 'prepared=true\n'), (None, None, 0, 'prepared=false\n'),
                 (None, TransportError('archive_status_mismatch'), 2, ''), (None, TransportError('signing_http_503'), 2, '')]
        for status, error, code, written in cases:
            with self.subTest(written=written, error=str(error)), tempfile.TemporaryDirectory() as temp:
                output = Path(temp) / 'github_output'
                output.write_text('')
                transport = ResumeTransport(status, error)
                with mock.patch.object(device_signer, 'release_identity', return_value=dict(identity)), \
                        mock.patch.object(device_signer, 'SigningTransport', return_value=transport), \
                        mock.patch.object(device_signer, 'GitHubOIDC'):
                    result = device_signer.main(['archive-resume', '--source-dir', temp, '--source-tag', TAG,
                                                 '--core-sha', CORE, '--github-output', str(output)],
                                                environ={'ZOLNIT_APPLE_DEVICE_SIGNING_ENABLED': 'true'})
                self.assertEqual((result, output.read_text()), (code, written))
                self.assertEqual(transport.registered, [(TAG, SOURCE, BUILD, ready)] if status else [])

    def test_every_mode_is_disabled_by_default(self):
        for argv in [['sign-one', '--config', '/x', '--workdir-root', '/tmp'], ['archive-publish', '--receipt', '/x']]:
            self.assertEqual(device_signer.main(argv, environ={}), 3)

    def test_archive_prepare_writes_private_receipt_bound_to_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = make_archive(root)
            (root / 'pubspec.yaml').write_text('version: 1.1.4+2026110805\n')

            def runner(argv):
                return subprocess.CompletedProcess(argv, 0, (CORE if 'Clash.Meta' in ' '.join(argv) else SOURCE) + '\n', '')
            receipt = archive_prepare(root, TAG, CORE, archive, root / 'a.zip', root / 'receipt.json', runner)
            self.assertEqual(stat.S_IMODE((root / 'receipt.json').stat().st_mode), 0o600)
            self.assertEqual(device_signer.read_receipt(root / 'receipt.json'), receipt)
            self.assertEqual((receipt['build'], receipt['core_sha']), (BUILD, CORE))


if __name__ == '__main__':
    unittest.main()
