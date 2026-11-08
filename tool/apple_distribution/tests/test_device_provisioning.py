import base64
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from device_provisioning import AppleAPI, ProvisioningError, ensure_device, ensure_profile


UDID = '00008110-0011223344556677'
DEVICE = {'device_id': 'a' * 32, 'udid': UDID}


class FakeAPI:
    def __init__(self, rows, created=None):
        self.values = rows
        self.created = created
        self.calls = []

    def rows(self, path):
        self.calls.append(('GET', path))
        return iter(self.values)

    def request(self, path, payload, method='GET'):
        self.calls.append((method, path, payload))
        return {'data': self.created}


class DeviceProvisioningTests(unittest.TestCase):
    def row(self, status='ENABLED', platform='IOS'):
        return {'id': 'DEVICE123', 'attributes': {'udid': UDID, 'status': status, 'platform': platform}}

    def test_existing_device_is_reused_without_mutation(self):
        api = FakeAPI([self.row()])
        self.assertEqual(ensure_device(api, DEVICE), 'DEVICE123')
        self.assertEqual([x[0] for x in api.calls], ['GET'])

    def test_disabled_duplicate_and_invalid_device_fail_before_registration(self):
        for rows in [[self.row('DISABLED')], [self.row(), self.row()], [self.row(platform='MAC_OS')]]:
            api = FakeAPI(rows)
            with self.assertRaises(ProvisioningError):
                ensure_device(api, DEVICE)
            self.assertEqual([x[0] for x in api.calls], ['GET'])
        api = FakeAPI([])
        with self.assertRaises(ProvisioningError):
            ensure_device(api, {'device_id': 'invalid', 'udid': UDID})
        self.assertFalse(api.calls)

    def test_registration_transmits_udid_only_in_body_and_opaque_name(self):
        api = FakeAPI([], self.row())
        self.assertEqual(ensure_device(api, DEVICE), 'DEVICE123')
        method, path, payload = api.calls[-1]
        self.assertEqual((method, path), ('POST', '/v1/devices'))
        self.assertEqual(payload['data']['attributes']['udid'], UDID)
        self.assertNotIn(UDID, payload['data']['attributes']['name'])
        self.assertNotIn(UDID, str(api.calls[:-1]))

    def test_pagination_rejects_foreign_origin_and_loops(self):
        api = AppleAPI(lambda: 'synthetic-only')
        api.request = lambda _: {'data': [], 'links': {'next': 'https://untrusted.invalid/v1/devices'}}
        with self.assertRaisesRegex(ProvisioningError, 'origin'):
            list(api.rows('/v1/devices?limit=200'))
        api.request = lambda _: {'data': [], 'links': {'next': 'https://api.appstoreconnect.apple.com/v1/devices'}}
        with self.assertRaisesRegex(ProvisioningError, 'loop'):
            list(api.rows('/v1/devices'))

    def test_profile_reuse_is_checked_against_device_and_certificate(self):
        name = 'ZolNit app ' + DEVICE['device_id'][:12] + ' 123'
        row = {'id': 'PROFILE123', 'attributes': {'name': name, 'profileType': 'IOS_APP_ADHOC',
               'profileState': 'ACTIVE', 'profileContent': base64.b64encode(b'synthetic-cms').decode()}}
        import hashlib
        certificate = b'synthetic-certificate'
        digest = hashlib.sha256(certificate).hexdigest()
        payload = {'ProvisionedDevices': [UDID], 'DeveloperCertificates': [certificate]}
        with tempfile.TemporaryDirectory() as temp, patch('device_provisioning.read_profile', return_value='verified'), patch('apple_distribution.profile_plist', return_value=payload):
            api = FakeAPI([row])
            result = ensure_profile(api, 'app', 'APP123', 'CERT123', 'DEVICE123', DEVICE['device_id'],
                                    123, UDID, digest, Path(temp) / 'profiles')
            self.assertEqual(result, 'verified')
            self.assertEqual([x[0] for x in api.calls], ['GET'])
        for mismatch in [{'ProvisionedDevices': ['00008110-0011223344556688'], 'DeveloperCertificates': [certificate]},
                         {'ProvisionedDevices': [UDID], 'DeveloperCertificates': [b'wrong']}]:
            with tempfile.TemporaryDirectory() as temp, patch('device_provisioning.read_profile', return_value='verified'), patch('apple_distribution.profile_plist', return_value=mismatch):
                with self.assertRaises(ProvisioningError):
                    ensure_profile(FakeAPI([row]), 'app', 'APP123', 'CERT123', 'DEVICE123', DEVICE['device_id'],
                                   123, UDID, digest, Path(temp) / 'profiles')


if __name__ == '__main__':
    unittest.main()
