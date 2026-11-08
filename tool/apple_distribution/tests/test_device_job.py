import hashlib
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile

from device_job import extract_verified_archive, process_job, validate_job
from device_provisioning import ProvisioningError


NOW = 1794135000


def job():
    return {'job_id': 'a' * 32, 'lease_token': 'b' * 43, 'lease_expires_at': NOW + 300,
            'team_id': '52QSDX4Y94', 'bundle_id': 'com.zolmid.zolnit',
            'device': {'device_id': 'c' * 32, 'udid': '00008110-0011223344556677'},
            'extensions': ['com.zolmid.zolnit.NECore', 'com.zolmid.zolnit.Widget'],
            'release': {'tag': 'v1.1.4', 'source_sha': 'd' * 40, 'build': 123,
                        'archive_key': 'apple-adhoc/archives/v1.1.4/archive.zip',
                        'archive_size': 1024, 'archive_sha256': 'e' * 64},
            'expected_artifact_key': 'apple-adhoc/signed/v1.1.4/' + 'a' * 32 + '.ipa'}


class DeviceJobTests(unittest.TestCase):
    def archive(self, directory, filename='Runner.xcarchive/Info.plist', mode=stat.S_IFREG | 0o644):
        path = directory / 'archive.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            item = zipfile.ZipInfo(filename)
            item.external_attr = mode << 16
            archive.writestr(item, b'synthetic payload' * 100)
        return path, {'archive_size': path.stat().st_size,
                      'archive_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def test_identity_and_path_mismatch_fail_closed(self):
        self.assertEqual(validate_job(job(), NOW)['team_id'], job()['team_id'])
        for key, value in [('team_id', 'WRONG'), ('expected_artifact_key', 'apple-adhoc/signed/wrong.ipa'),
                           ('extensions', ['com.zolmid.zolnit.NECore']), ('lease_expires_at', NOW)]:
            candidate = job()
            candidate[key] = value
            with self.assertRaises(ProvisioningError):
                validate_job(candidate, NOW)

    def test_verified_archive_preserves_execute_and_rejects_traversal_symlinks_digest(self):
        for filename, mode in [('Runner.xcarchive/../escape', stat.S_IFREG | 0o600),
                               ('Runner.xcarchive/link', stat.S_IFLNK | 0o777),
                               ('foreign/file', stat.S_IFREG | 0o600)]:
            with tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                path, release = self.archive(directory, filename, mode)
                with self.assertRaises(ProvisioningError):
                    extract_verified_archive(path, directory / 'out', release)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path, release = self.archive(directory, 'Runner.xcarchive/Runner', stat.S_IFREG | 0o755)
            result = extract_verified_archive(path, directory / 'out', release)
            self.assertTrue((result / 'Runner').stat().st_mode & 0o111)
            release['archive_sha256'] = '0' * 64
            with self.assertRaises(ProvisioningError):
                extract_verified_archive(path, directory / 'bad', release)

    def test_job_only_completes_after_matching_storage_attestation(self):
        for mismatch in [False, True]:
            with tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                archive, release = self.archive(directory)
                candidate = job()
                candidate['release'].update(release)
                calls = []

                def provision(j, path):
                    calls.append('provision')
                    return {'expires_at': NOW + 86400, 'apple_device_resource_id': 'DEVICE123'}

                def export(j, path, credentials, output):
                    calls.append('export')
                    output.mkdir()
                    ipa = output / 'Runner.ipa'
                    ipa.write_bytes(b'a' * 2048)
                    return ipa

                def upload(j, ipa, digest, size):
                    calls.append('upload')
                    return {'artifact_key': j['expected_artifact_key'], 'sha256': '0' * 64 if mismatch else digest, 'size': size}

                def complete(payload):
                    calls.append('complete')
                    self.assertNotIn('udid', payload)
                    self.assertEqual(payload['outcome'], 'ready')
                    return {'status': 'ready'}

                if mismatch:
                    with self.assertRaises(ProvisioningError):
                        process_job(candidate, archive, directory / 'job', provision, export, upload, complete, now=lambda: NOW)
                    self.assertNotIn('complete', calls)
                else:
                    result = process_job(candidate, archive, directory / 'job', provision, export, upload, complete, now=lambda: NOW)
                    self.assertEqual(result, {'status': 'ready'})
                    self.assertEqual(calls, ['provision', 'export', 'upload', 'complete'])


if __name__ == '__main__':
    unittest.main()
