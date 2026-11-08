import hashlib
import hmac
import base64
import io
import json
from email.message import Message
from pathlib import Path
import tempfile
import unittest
import urllib.error

from signing_transport import SigningTransport, TransportError, ORIGIN

NOW = 1000
TAG = 'v1.1.4'
SOURCE = 'a' * 40
SESSION = '11111111-1111-4111-8111-111111111111'


class Response(io.BytesIO):
    def __init__(self, request, data, status=200, headers=None, url=None):
        super().__init__(data if isinstance(data, bytes) else json.dumps(data).encode())
        self.status = status
        self.url = url or request.full_url
        self.headers = Message()
        for key, value in (headers or {'Content-Type': 'application/json'}).items():
            self.headers[key] = value

    def geturl(self):
        return self.url


class Opener:
    def __init__(self, callback):
        self.callback = callback
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        assert timeout == 45
        return self.callback(request)


class SigningTransportTests(unittest.TestCase):
    def test_archive_upload_exact_hmac_and_part_contract(self):
        content = b'x' * 1024
        digest = hashlib.sha256(content).hexdigest()
        key = 'apple-adhoc/archives/v1.1.4/ZolNit-1.1.4-ios-arm64.xcarchive.zip'
        def handle(request):
            path = request.full_url.removeprefix(ORIGIN)
            if path.endswith('/authorize'):
                self.assertEqual(json.loads(request.data), {'schema_version': 1, 'tag': TAG, 'source_sha': SOURCE, 'build': 114})
                return Response(request, {'data': {'lease': 's' * 43, 'expires_at': NOW + 3600}})
            if path.endswith('/archives/sessions'):
                payload = json.loads(request.data)
                message = ':'.join(map(str, ['zolnit-apple-archive-v1', TAG, SOURCE, 114, key, digest, 1024, NOW + 300]))
                expected = base64.urlsafe_b64encode(hmac.new(('s' * 43).encode(), message.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()
                self.assertEqual(payload['origin_grant'], expected)
                self.assertEqual(payload['archive_key'], key)
                return Response(request, {'id': SESSION, 'state': 'uploading', 'max_part_bytes': 8 * 1024 * 1024})
            if '/parts/' in path:
                self.assertEqual(request.data, content)
                self.assertEqual(request.get_header('X-final-part'), 'true')
                return Response(request, b'', 204)
            if path.endswith('/complete'):
                return Response(request, {'state': 'ready', 'archive_key': key, 'archive_sha256': digest, 'archive_size': 1024})
            self.fail('unexpected path')
        opener = Opener(handle)
        client = SigningTransport(lambda: 'synthetic-oidc', opener, now=lambda: NOW)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'archive.zip'
            path.write_bytes(content)
            client.upload_archive(path, TAG, SOURCE, 114)
        self.assertEqual(len(opener.requests), 4)
        self.assertTrue(all('synthetic-oidc' not in r.full_url and '?' not in r.full_url for r in opener.requests))

    def test_archive_download_verified_permissions_and_digest_failure_cleanup(self):
        content = b'z' * 1024
        expected = hashlib.sha256(content).hexdigest()
        corrupt = False
        def handle(request):
            return Response(request, b'q' * 1024 if corrupt else content, headers={
                'Content-Length': '1024', 'X-Archive-Sha256': expected, 'X-Archive-Tag': TAG, 'X-Source-Sha': SOURCE})
        client = SigningTransport(lambda: 'synthetic', Opener(handle))
        release = {'tag': TAG, 'source_sha': SOURCE, 'archive_sha256': expected, 'archive_size': 1024}
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'archive.zip'
            client.download_archive(release, target)
            self.assertEqual(target.read_bytes(), content)
            self.assertEqual(target.stat().st_mode & 0o077, 0)
            corrupt = True
            failed = Path(folder) / 'bad.zip'
            with self.assertRaisesRegex(TransportError, 'archive_digest_mismatch'):
                client.download_archive(release, failed)
            self.assertFalse(failed.exists())

    def test_signed_upload_claim_renew_and_complete_preserve_job_lease(self):
        content = b'i' * 1024
        digest = hashlib.sha256(content).hexdigest()
        job_id, lease = 'b' * 32, 'l' * 43
        artifact_key = 'apple-adhoc/signed/' + TAG + '/' + job_id + '.ipa'
        job = {'team_id': '52QSDX4Y94', 'bundle_id': 'com.zolmid.zolnit', 'job_id': job_id,
               'lease_token': lease, 'lease_expires_at': NOW + 300,
               'device': {'device_id': 'c' * 32, 'udid': '00008110-0011223344556677'},
               'release': {'tag': TAG, 'source_sha': SOURCE, 'build': 114, 'archive_sha256': 'd' * 64,
                           'archive_size': 2048, 'archive_key': 'apple-adhoc/archives/' + TAG + '/archive.zip'},
               'extensions': ['com.zolmid.zolnit.NECore', 'com.zolmid.zolnit.Widget'],
               'expected_artifact_key': artifact_key}
        def handle(request):
            path = request.full_url.removeprefix(ORIGIN)
            if path.endswith('/authorize'):
                return Response(request, {'data': {'lease': 's' * 43, 'expires_at': NOW + 3600}})
            if path.endswith('/claim'):
                return Response(request, {'data': {'job': job}})
            if path.endswith('/renew'):
                self.assertEqual(json.loads(request.data), {'job_id': job_id, 'lease_token': lease})
                return Response(request, {'data': {'job_id': job_id, 'status': 'leased', 'lease_expires_at': NOW + 350}})
            if path.endswith('/signed/sessions'):
                payload = json.loads(request.data)
                message = ':'.join(map(str, ['zolnit-apple-sign-v1', job_id, hashlib.sha256(lease.encode()).hexdigest(),
                                  NOW + 300, TAG, SOURCE, 114, 'd' * 64, artifact_key]))
                expected = base64.urlsafe_b64encode(hmac.new(('s' * 43).encode(), message.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()
                self.assertEqual(payload['origin_grant'], expected)
                self.assertEqual(payload['lease_token'], lease)
                return Response(request, {'id': SESSION, 'state': 'uploading', 'max_part_bytes': 8 * 1024 * 1024})
            if '/signed/sessions/' in path:
                self.assertEqual(request.get_header('X-signing-lease'), lease)
                if '/parts/' in path:
                    self.assertEqual(request.data, content)
                    return Response(request, b'', 204)
                return Response(request, {'state': 'ready', 'artifact_key': artifact_key,
                                         'artifact_sha256': digest, 'artifact_size': 1024, 'artifact_expires_at': NOW + 3600})
            if path.endswith('/signer/complete'):
                self.assertEqual(json.loads(request.data)['lease_token'], lease)
                return Response(request, {'data': {'job_id': job_id, 'status': 'ready'}})
            self.fail('unexpected signed upload request')
        opener = Opener(handle)
        client = SigningTransport(lambda: 'synthetic-oidc', opener, now=lambda: NOW)
        self.assertEqual(client.claim_job(), job)
        self.assertEqual(client.renew_job(job)['lease_expires_at'], NOW + 350)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'signed.ipa'
            path.write_bytes(content)
            stored = client.upload_signed(job, path, digest, 1024, NOW + 3600)
        self.assertEqual(stored, {'artifact_key': artifact_key, 'sha256': digest, 'size': 1024, 'expires_at': NOW + 3600})
        self.assertEqual(client.complete_job({'job_id': job_id, 'lease_token': lease, 'outcome': 'ready'})['status'], 'ready')
        self.assertTrue(all(lease not in request.full_url for request in opener.requests))

    def test_transport_rejects_redirect_headers_query_and_oversized_json(self):
        cases = [
            (lambda r: Response(r, {}, url='https://example.invalid/'), 'signing_redirect_rejected'),
            (lambda r: Response(r, b'x' * 65537), 'signing_response_too_large'),
        ]
        for handler, error in cases:
            client = SigningTransport(lambda: 'synthetic', Opener(handler))
            with self.assertRaisesRegex(TransportError, error):
                client.authorize_archive(TAG, SOURCE, 114)
        client = SigningTransport(lambda: 'synthetic', Opener(lambda r: self.fail('must not send')))
        with self.assertRaisesRegex(TransportError, 'signing_path_rejected'):
            client._open('/api/v1/zolnit/client/apple/signer/claim?token=secret')
        client = SigningTransport(lambda: 'bad' + chr(10) + 'token', Opener(lambda r: self.fail('must not send')))
        with self.assertRaisesRegex(TransportError, 'signing_identity_invalid'):
            client.authorize_archive(TAG, SOURCE, 114)

    def test_http_errors_do_not_expose_response_or_credentials(self):
        def handle(request):
            raise urllib.error.HTTPError(request.full_url, 403, 'secret response', {}, io.BytesIO(b'private-value'))
        client = SigningTransport(lambda: 'credential-value', Opener(handle))
        with self.assertRaises(TransportError) as caught:
            client.authorize_archive(TAG, SOURCE, 114)
        self.assertEqual(str(caught.exception), 'signing_http_403')


if __name__ == '__main__':
    unittest.main()
