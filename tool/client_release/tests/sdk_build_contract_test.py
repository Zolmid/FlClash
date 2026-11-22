import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]

class SdkBuildContractTest(unittest.TestCase):
    def test_release_artifacts_are_pinned_and_not_debug_only(self):
        android = (ROOT / 'android/app/build.gradle.kts').read_text()
        self.assertIn('add("implementation", "com.alibaba.pdns:alidns-android-sdk:2.3.3")', android)
        self.assertIn('48722b25b2a546253148e246737c3350fc28dff56c6f1e38528b6605dde7dbb5', android)
        podspec = (ROOT / 'ios/CloudDnsSdk/ZolnitCloudDnsSdk.podspec').read_text()
        self.assertIn('b81532101dac5ed2ddf195f10607bb6f94627aca398561f91c56c351afd25444', podspec)
        self.assertIn('ZOLNIT_CLOUD_DNS_SDK=1', podspec)
        objc = (ROOT / 'ios/Runner/OwnedDnsSdkBridge.m').read_text()
        self.assertNotIn('DEBUG &&', objc)
        self.assertIn('getIpv4DataWithDomain', objc)
        self.assertIn('getIpv6DataWithDomain', objc)

    def test_fixed_signer_legacy_env_enables_pod_hook_even_with_stale_generated_defines(self):
        import tempfile
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'ios/Flutter').mkdir(parents=True)
            # Exact public prepare-source env from immutable signer 97f29774.
            env = {'APP_ENV': 'stable', 'ZOLNIT_DISTRIBUTION': 'direct', 'ZOLNIT_NATIVE_UI': 'true', 'ZOLNIT_CLIENT_BUNDLE': 'true'}
            (root / 'env.json').write_text(json.dumps(env))
            (root / 'ios/Flutter/Generated.xcconfig').write_text('DART_DEFINES=QVBQX0VOVj1kZXY=\n')
            source = (ROOT / 'ios/Podfile').read_text()
            helper = source[source.index('def zolnit_cloud_dns_sdk_enabled?'):source.index("target 'Runner' do")]
            file = root / 'ios/Podfile'
            file.write_text("require 'json'\nrequire 'base64'\n" + helper + "\nabort('SDK omitted') unless zolnit_cloud_dns_sdk_enabled?\n")
            subprocess.run(['ruby', str(file)], check=True, capture_output=True, env={k:v for k,v in os.environ.items() if k != 'ZOLNIT_CLOUD_DNS_SDK'})

    def test_cleartext_is_only_loopback(self):
        import plistlib
        value = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())['NSAppTransportSecurity']
        self.assertNotIn('NSAllowsArbitraryLoads', value)
        self.assertNotIn('NSAllowsLocalNetworking', value)
        self.assertEqual(set(value['NSExceptionDomains']), {'127.0.0.1'})
        xml = (ROOT / 'android/app/src/main/res/xml/zolnit_loopback_security.xml').read_text()
        self.assertIn('<base-config cleartextTrafficPermitted="false"', xml)
        self.assertEqual(re.findall(r'<domain[^>]*>([^<]+)</domain>', xml), ['127.0.0.1'])

if __name__ == '__main__':
    unittest.main()
