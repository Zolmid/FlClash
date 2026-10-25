#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description='Build only the unsigned iOS lease observer acceptance app')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--app-bundle-id', default='com.zolmid.zolnit.debug')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+', args.app_bundle_id):
        parser.error('invalid base app bundle identifier')
    if args.output.exists():
        parser.error('output directory must not already exist')
    for command in (['xcrun', '--find', 'xcodebuild'], ['xcrun', '--sdk', 'iphoneos', '--show-sdk-path']):
        try:
            result = subprocess.run(command, capture_output=True, text=True)
        except FileNotFoundError:
            result = None
        if result is None or result.returncode:
            print(json.dumps({'ok': False, 'code': 'xcode_iphoneos_sdk_unavailable', 'artifact_created': False}))
            return 2
    repo = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='zolnit-ios-observer-') as temporary:
        source = Path(temporary) / 'source'
        shutil.copytree(repo / 'ios/LeaseObserver', source / 'LeaseObserver')
        (source / 'Shared').mkdir()
        shutil.copy2(repo / 'ios/Shared/RoutingLeaseObservationReader.swift', source / 'Shared/RoutingLeaseObservationReader.swift')
        derived = Path(temporary) / 'DerivedData'
        command = [
            'xcrun', 'xcodebuild', '-project', str(source / 'LeaseObserver/LeaseObserver.xcodeproj'),
            '-scheme', 'LeaseObserverAcceptance', '-configuration', 'Debug', '-sdk', 'iphoneos',
            '-destination', 'generic/platform=iOS', '-derivedDataPath', str(derived),
            '-disableAutomaticPackageResolution', 'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=NO',
            'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=',
            'DEVELOPMENT_TEAM=', 'PROVISIONING_PROFILE_SPECIFIER=', 'ZOLNIT_OBSERVER_ACCEPTANCE=YES',
            'APP_BUNDLE_ID=' + args.app_bundle_id, 'build',
        ]
        with (output / 'xcodebuild.log').open('w') as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(json.dumps({'ok': False, 'code': 'unsigned_build_failed', 'artifact_created': False}))
            return result.returncode
        app = derived / 'Build/Products/Debug-iphoneos/ZolNitLeaseObserver.app'
        if not app.is_dir() or (app / '_CodeSignature').exists():
            raise RuntimeError('unsigned observer app missing or unexpectedly signed')
        with (app / 'Info.plist').open('rb') as stream:
            info = plistlib.load(stream)
        if info['CFBundleIdentifier'] != args.app_bundle_id + '.LeaseObserver' or info['ZolNitObserverAppGroup'] != 'group.' + args.app_bundle_id:
            raise RuntimeError('observer bundle and App Group identity mismatch')
        executable = app / info['CFBundleExecutable']
        payload = output / 'Payload'
        payload.mkdir()
        shutil.copytree(app, payload / app.name, symlinks=True)
        ipa = output / 'ZolNitLeaseObserver-unsigned.ipa'
        with zipfile.ZipFile(ipa, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for entry in sorted(payload.rglob('*')):
                archive.write(entry, entry.relative_to(output))
        commit = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
        dirty = bool(subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain']))
        print(json.dumps({'ok': True, 'code': 'ios_observer_unsigned_build', 'source_commit': commit,
                          'working_tree_dirty': dirty, 'ipa_sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
                          'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
                          'signed': False, 'device_executed': False}))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
