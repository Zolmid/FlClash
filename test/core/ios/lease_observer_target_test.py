import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OBSERVER = ROOT / 'ios/LeaseObserver'


class ObserverTargetContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        data = subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(OBSERVER / 'LeaseObserver.xcodeproj/project.pbxproj')])
        cls.project = json.loads(data)
        cls.objects = cls.project['objects']

    def test_only_observer_sources_and_no_core_or_app_dependency(self):
        targets = [item for item in self.objects.values() if item['isa'] == 'PBXNativeTarget']
        self.assertEqual(len(targets), 1)
        target = targets[0]
        self.assertEqual(target['name'], 'LeaseObserver')
        self.assertEqual(target['dependencies'], [])
        sources = next(self.objects[key] for key in target['buildPhases'] if self.objects[key]['isa'] == 'PBXSourcesBuildPhase')
        paths = {self.objects[self.objects[key]['fileRef']]['path'] for key in sources['files']}
        self.assertEqual(paths, {'LeaseObserverApp.swift', 'LeaseObservationPresentation.swift', '../Shared/RoutingLeaseObservationReader.swift'})
        for path in paths:
            self.assertTrue((OBSERVER / path).is_file())
        self.assertFalse(any(item['isa'] in ('PBXCopyFilesBuildPhase', 'XCRemoteSwiftPackageReference') for item in self.objects.values()))

    def test_app_group_matches_existing_convention_and_has_no_vpn_privilege(self):
        with (OBSERVER / 'LeaseObserver.entitlements').open('rb') as stream:
            observer = plistlib.load(stream)
        with (ROOT / 'ios/Runner/Runner.entitlements').open('rb') as stream:
            runner = plistlib.load(stream)
        self.assertEqual(observer, {'com.apple.security.application-groups': runner['com.apple.security.application-groups']})
        with (OBSERVER / 'Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        self.assertEqual(info['ZolNitObserverAppGroup'], 'group.$(APP_BUNDLE_ID)')
        self.assertNotIn('CFBundleURLTypes', info)
        self.assertNotIn('UIBackgroundModes', info)

    def test_acceptance_gate_rejects_default_release_and_archive(self):
        gate = next(item['shellScript'] for item in self.objects.values() if item['isa'] == 'PBXShellScriptBuildPhase')
        for configuration, opt_in, action, expected in [
            ('Debug', 'NO', 'build', 1), ('Release', 'YES', 'build', 1),
            ('Debug', 'YES', 'install', 1), ('Debug', 'YES', 'build', 0),
        ]:
            result = subprocess.run(['/bin/sh', '-c', gate], env={**os.environ, 'CONFIGURATION': configuration,
                                    'ZOLNIT_OBSERVER_ACCEPTANCE': opt_in, 'ACTION': action}, capture_output=True)
            self.assertEqual(result.returncode, expected)
        scheme = ET.parse(OBSERVER / 'LeaseObserver.xcodeproj/xcshareddata/xcschemes/LeaseObserverAcceptance.xcscheme')
        self.assertEqual(scheme.find('.//BuildActionEntry').attrib['buildForArchiving'], 'NO')
        self.assertEqual({item['name'] for item in self.objects.values() if item['isa'] == 'XCBuildConfiguration'}, {'Debug'})


    def test_failed_unsigned_build_uses_and_cleans_private_source_copy(self):
        with tempfile.TemporaryDirectory(prefix='observer-builder-test-') as temporary:
            root = Path(temporary)
            shim = root / 'xcrun'
            record = root / 'project-path.txt'
            shim.write_text(
                '#!' + sys.executable + '\n'
                'import os, pathlib, sys\n'
                'args = sys.argv[1:]\n'
                'if args[0] != "xcodebuild":\n'
                '    print("test-only-preflight"); sys.exit(0)\n'
                'project = pathlib.Path(args[args.index("-project") + 1]).resolve()\n'
                'assert not project.is_relative_to(pathlib.Path(os.environ["OBSERVER_REPO"]))\n'
                'assert (project.parent / "LeaseObserverApp.swift").is_file()\n'
                'assert (project.parent.parent / "Shared/RoutingLeaseObservationReader.swift").is_file()\n'
                'pathlib.Path(os.environ["OBSERVER_PROJECT_RECORD"]).write_text(str(project))\n'
                '(project / "generated-workspace-test").write_text("owned test metadata")\n'
                'sys.exit(17)\n'
            )
            shim.chmod(0o700)
            output = root / 'unsigned'
            env = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                   'OBSERVER_REPO': str(ROOT), 'OBSERVER_PROJECT_RECORD': str(record)}
            result = subprocess.run([sys.executable, str(ROOT / 'tool/acceptance/build_ios_observer.py'),
                                     '--output', str(output)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 17, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)['code'], 'unsigned_build_failed')
            self.assertFalse(Path(record.read_text()).exists())
            self.assertFalse((output / 'ZolNitLeaseObserver-unsigned.ipa').exists())
            self.assertTrue((output / 'xcodebuild.log').is_file())


if __name__ == '__main__':
    unittest.main()
