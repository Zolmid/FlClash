import io
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sdk_verification import SdkArtifactError, dex_has_vendor_definition, verify_android_apk, verify_ios_executable
from sdk_fixtures import apk_bytes, dex_bytes, macho_bytes


class SdkVerificationTest(unittest.TestCase):
    def test_ios_checks_actual_objc_sections_and_keeps_runtime_unverified(self):
        binary = macho_bytes()
        proof = verify_ios_executable(io.BytesIO(binary), len(binary))
        self.assertEqual(proof['level'], 'L0-artifact')
        self.assertEqual(proof['ios_physical_runtime'], 'not_verified_by_this_check')
        for binary in [macho_bytes(classes=b'OwnedDnsSdkBridge\0'),
                       macho_bytes(classes=b'DNSResolver\0'), macho_bytes(fusion=False),
                       macho_bytes(cpu=0x01000007), b'not macho']:
            with self.assertRaises(SdkArtifactError):
                verify_ios_executable(io.BytesIO(binary), len(binary))

    def test_ios_metadata_in_resources_or_other_sections_cannot_pass(self):
        binary = macho_bytes().replace(b'__objc_classname', b'__cstring'.ljust(15, b'\0'))
        with self.assertRaises(SdkArtifactError):
            verify_ios_executable(io.BytesIO(binary), len(binary))
        binary = bytearray(macho_bytes())
        struct.pack_into('<Q', binary, 32 + 72 + 40, 0xffffffff)
        with self.assertRaises(SdkArtifactError):
            verify_ios_executable(io.BytesIO(binary), len(binary))

    def test_android_requires_vendor_definition_not_reference_or_unminified_app_bridge(self):
        self.assertTrue(dex_has_vendor_definition(dex_bytes()))
        self.assertFalse(dex_has_vendor_definition(dex_bytes(defined=False)))
        self.assertFalse(dex_has_vendor_definition(dex_bytes(fusion=False)))
        for binary in [b'fake', dex_bytes()[:100], dex_bytes().replace(b'dex\n', b'cdex', 1)]:
            with self.assertRaises(SdkArtifactError): dex_has_vendor_definition(binary)
        with tempfile.TemporaryDirectory() as folder:
            apk = Path(folder) / 'release.apk'
            apk.write_bytes(apk_bytes())
            proof = verify_android_apk(apk)
            self.assertEqual(proof['level'], 'L0-artifact')
            self.assertNotIn('OwnedDnsSdkBridge', str(proof))
            apk.write_bytes(apk_bytes(defined=False))
            with self.assertRaises(SdkArtifactError): verify_android_apk(apk)


if __name__ == '__main__': unittest.main()
