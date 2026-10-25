#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import zipfile


def require(value, message):
    if not value:
        raise ValueError(message)


def ad_hoc_entitlements(binary):
    require(len(binary) >= 32 and binary[:4] == b'\xcf\xfa\xed\xfe', 'expected thin arm64 Mach-O')
    require(struct.unpack_from('<I', binary, 4)[0] == 0x0100000c, 'unexpected CPU architecture')
    count, size = struct.unpack_from('<II', binary, 16)
    require(count <= 4096 and 32 + size <= len(binary), 'invalid Mach-O commands')
    offset, signature = 32, None
    for _ in range(count):
        require(offset + 8 <= 32 + size, 'truncated load command')
        command, length = struct.unpack_from('<II', binary, offset)
        require(length >= 8 and offset + length <= 32 + size, 'invalid load command')
        if command == 0x1d:
            require(length >= 16 and signature is None, 'invalid code signature command')
            start, extent = struct.unpack_from('<II', binary, offset + 8)
            require(start + extent <= len(binary), 'truncated code signature')
            signature = binary[start:start + extent]
        offset += length
    require(signature is not None and len(signature) >= 12, 'missing ad hoc signature')
    magic, total, entries = struct.unpack_from('>III', signature)
    require(magic == 0xfade0cc0 and total <= len(signature) and entries <= 64 and 12 + entries * 8 <= total, 'invalid signature container')
    flags, entitlements = [], None
    for index in range(entries):
        kind, start = struct.unpack_from('>II', signature, 12 + index * 8)
        require(start + 8 <= total, 'invalid signature slot')
        blob_magic, length = struct.unpack_from('>II', signature, start)
        require(length >= 8 and start + length <= total, 'truncated signature slot')
        blob = signature[start:start + length]
        if blob_magic == 0xfade0c02:
            require(length >= 16, 'invalid CodeDirectory')
            flags.append(struct.unpack_from('>I', blob, 12)[0])
        if kind == 0x10000:
            require(length == 8, 'developer CMS signature is outside unsigned acceptance')
        if kind == 5:
            require(blob_magic == 0xfade7171 and entitlements is None, 'invalid entitlement slot')
            entitlements = plistlib.loads(blob[8:])
    require(flags and all(flag & 2 for flag in flags), 'expected ad hoc placeholder signing')
    require(isinstance(entitlements, dict), 'missing entitlement plist')
    return entitlements


def validate(client, observer, base, commit):
    require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None, 'invalid source commit')
    group = 'group.' + base
    identifiers = []
    with zipfile.ZipFile(client) as bundle:
        names = bundle.namelist()
        require(len(names) == len(set(names)) and bundle.testzip() is None, 'invalid client archive')
        require(not any(name.endswith('/embedded.mobileprovision') for name in names), 'unexpected provisioning')
        for suffix, prefix in [('', 'Payload/Runner.app/'), ('.NECore', 'Payload/Runner.app/PlugIns/NECore.appex/'), ('.Widget', 'Payload/Runner.app/PlugIns/Widget.appex/')]:
            info = plistlib.loads(bundle.read(prefix + 'Info.plist'))
            identifier = base + suffix
            require(info['CFBundleIdentifier'] == identifier, 'client bundle identifier mismatch')
            executable = info['CFBundleExecutable']
            require(isinstance(executable, str) and '/' not in executable and executable not in ('', '.', '..'), 'invalid executable name')
            entitlements = ad_hoc_entitlements(bundle.read(prefix + executable))
            require(entitlements.get('com.apple.security.application-groups') == [group], 'client App Group mismatch')
            require(entitlements.get('application-identifier') == 'UNKNOWN000.' + identifier, 'unexpected signing identity')
            require(entitlements.get('com.apple.developer.team-identifier') == 'UNKNOWN000', 'unexpected developer team')
            if suffix in ('', '.NECore'):
                require('packet-tunnel-provider' in entitlements.get('com.apple.developer.networking.networkextension', []), 'missing Packet Tunnel declaration')
            identifiers.append(identifier)
    with zipfile.ZipFile(observer) as bundle:
        names = bundle.namelist()
        require(len(names) == len(set(names)) and bundle.testzip() is None, 'invalid observer archive')
        require(not any('/_CodeSignature/' in name or name.endswith('/embedded.mobileprovision') for name in names), 'observer must remain unsigned')
        info = plistlib.loads(bundle.read('Payload/ZolNitLeaseObserver.app/Info.plist'))
        require(info['CFBundleIdentifier'] == base + '.LeaseObserver', 'observer bundle identifier mismatch')
        require(info['ZolNitObserverAppGroup'] == group, 'observer App Group mismatch')
        identifiers.append(info['CFBundleIdentifier'])
    return {'ok': True, 'code': 'unsigned_ios_pair_verified', 'source_commit': commit,
            'app_group': group, 'bundles': identifiers, 'main_signing': 'ad_hoc_placeholder',
            'observer_signing': 'unsigned', 'device_installable': False, 'device_executed': False,
            'client_sha256': hashlib.sha256(Path(client).read_bytes()).hexdigest(),
            'observer_sha256': hashlib.sha256(Path(observer).read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description='Validate actual unsigned client/observer IPA pairing')
    parser.add_argument('--client', required=True, type=Path)
    parser.add_argument('--observer', required=True, type=Path)
    parser.add_argument('--base-bundle-id', required=True)
    parser.add_argument('--source-commit', required=True)
    args = parser.parse_args()
    print(json.dumps(validate(args.client, args.observer, args.base_bundle_id, args.source_commit)))


if __name__ == '__main__':
    main()
