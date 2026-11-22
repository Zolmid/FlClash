"""L0 SDK-presence checks on the packaged mobile executable, not device acceptance."""
from __future__ import annotations

import struct

IOS_CLASSES = (b'DNSResolver', b'OwnedDnsSdkBridge')
IOS_FUSION_SELECTOR = b'setFusionDNSWithIPv4:IPv6:Host:Port:HealthCheckDomain:accessKeyId:accesskeySecret:'
ANDROID_CLASS = b'Lcom/alibaba/pdns/DNSResolver;'
ANDROID_METHOD = b'InitFusionDNS'


class SdkArtifactError(ValueError):
    pass


def need(condition, message):
    if not condition:
        raise SdkArtifactError(message)


def verify_ios_executable(stream, size):
    header = stream.read(32)
    need(len(header) == 32, 'iOS SDK: truncated Mach-O header')
    magic, cpu, _, filetype, commands, command_bytes, _, _ = struct.unpack('<8I', header)
    need(magic == 0xfeedfacf and cpu == 0x0100000c and filetype == 2,
         'iOS SDK: main executable is not an arm64 Mach-O executable')
    need(commands <= 4096 and command_bytes <= 1024 * 1024 and 32 + command_bytes <= size,
         'iOS SDK: invalid load commands')
    data = stream.read(command_bytes)
    need(len(data) == command_bytes, 'iOS SDK: truncated load commands')
    sections = {}
    cursor = 0
    for _ in range(commands):
        need(cursor + 8 <= len(data), 'iOS SDK: truncated load command')
        kind, length = struct.unpack_from('<II', data, cursor)
        need(length >= 8 and cursor + length <= len(data), 'iOS SDK: invalid load command size')
        if kind == 0x19:
            need(length >= 72, 'iOS SDK: truncated segment')
            count = struct.unpack_from('<I', data, cursor + 64)[0]
            need(72 + count * 80 <= length, 'iOS SDK: invalid section table')
            for index in range(count):
                section = cursor + 72 + index * 80
                name = data[section:section + 16].rstrip(b'\0')
                if name not in (b'__objc_classname', b'__objc_methname'):
                    continue
                amount = struct.unpack_from('<Q', data, section + 40)[0]
                offset = struct.unpack_from('<I', data, section + 48)[0]
                need(amount <= 64 * 1024 * 1024 and offset + amount <= size,
                     'iOS SDK: invalid Objective-C metadata bounds')
                stream.seek(offset)
                value = stream.read(amount)
                need(len(value) == amount, 'iOS SDK: truncated Objective-C metadata')
                sections.setdefault(name, set()).update(value.split(b'\0'))
        cursor += length
    names = sections.get(b'__objc_classname', set())
    need(all(name in names for name in IOS_CLASSES), 'iOS SDK: official SDK or app bridge class missing from Runner')
    need(IOS_FUSION_SELECTOR in sections.get(b'__objc_methname', set()),
         'iOS SDK: stable FusionDNS selector missing from Runner')
    return {'level': 'L0-artifact', 'format': 'arm64-macho-objc',
            'classes': [name.decode() for name in IOS_CLASSES],
            'fusion_selector': IOS_FUSION_SELECTOR.decode(),
            'ios_physical_runtime': 'not_verified_by_this_check'}


def dex_has_vendor_definition(data):
    need(len(data) >= 112 and data[:4] == b'dex\n' and data[7] == 0,
         'Android SDK: invalid DEX header')
    file_size, header_size, endian = struct.unpack_from('<III', data, 32)
    need(file_size == len(data) and header_size >= 112 and endian == 0x12345678,
         'Android SDK: unsupported or truncated DEX layout')

    def table(position, width):
        count, offset = struct.unpack_from('<II', data, position)
        need(offset + count * width <= len(data), 'Android SDK: DEX table out of bounds')
        return count, offset

    strings, string_offset = table(56, 4)
    types, type_offset = table(64, 4)
    methods, method_offset = table(88, 8)
    classes, class_offset = table(96, 32)

    def uleb(offset):
        value = 0
        for shift in range(0, 35, 7):
            need(offset < len(data), 'Android SDK: truncated DEX ULEB128')
            part = data[offset]
            offset += 1
            value |= (part & 127) << shift
            if part < 128:
                return value, offset
        raise SdkArtifactError('Android SDK: invalid DEX ULEB128')

    def string(index):
        need(index < strings, 'Android SDK: invalid DEX string index')
        offset = struct.unpack_from('<I', data, string_offset + index * 4)[0]
        _, offset = uleb(offset)
        end = data.find(b'\0', offset, min(len(data), offset + 8192))
        need(end >= offset, 'Android SDK: unterminated DEX identifier')
        return data[offset:end]

    vendor_types = {index for index in range(types)
                    if string(struct.unpack_from('<I', data, type_offset + index * 4)[0]) == ANDROID_CLASS}
    for index in range(classes):
        offset = class_offset + index * 32
        owner = struct.unpack_from('<I', data, offset)[0]
        if owner not in vendor_types:
            continue
        cursor = struct.unpack_from('<I', data, offset + 24)[0]
        if not cursor:
            continue
        sizes = []
        for _ in range(4):
            value, cursor = uleb(cursor)
            sizes.append(value)
        need(sum(sizes) <= len(data), 'Android SDK: invalid DEX class-data sizes')
        for _ in range(sizes[0] + sizes[1]):
            _, cursor = uleb(cursor)
            _, cursor = uleb(cursor)
        for count in sizes[2:]:
            method_index = 0
            for _ in range(count):
                difference, cursor = uleb(cursor)
                _, cursor = uleb(cursor)
                code, cursor = uleb(cursor)
                method_index += difference
                need(method_index < methods, 'Android SDK: invalid DEX method index')
                declared_owner, _, name_index = struct.unpack_from('<HHI', data, method_offset + method_index * 8)
                if declared_owner == owner and string(name_index) == ANDROID_METHOD:
                    need(code > 0 and code + 16 <= len(data), 'Android SDK: FusionDNS method has no code')
                    units = struct.unpack_from('<I', data, code + 12)[0]
                    need(units > 0 and code + 16 + units * 2 <= len(data),
                         'Android SDK: truncated FusionDNS code')
                    return True
    return False


def verify_android_apk(apk):
    import re
    import zipfile
    with zipfile.ZipFile(apk) as archive:
        entries = [entry for entry in archive.infolist() if re.fullmatch(r'classes(?:[2-9]|[1-9][0-9]+)?\.dex', entry.filename)]
        need(entries and len({entry.filename for entry in entries}) == len(entries), 'Android SDK: missing or duplicate DEX entries')
        found = False
        for entry in entries:
            need(entry.file_size <= 128 * 1024 * 1024, 'Android SDK: oversized DEX')
            found = dex_has_vendor_definition(archive.read(entry)) or found
        need(found, 'Android SDK: official DNSResolver class and defined InitFusionDNS method missing')
    return {'level': 'L0-artifact', 'format': 'dex-class-and-method-definition',
            'vendor_class': ANDROID_CLASS.decode(), 'vendor_method': ANDROID_METHOD.decode(),
            'runtime': 'not_verified_by_this_check'}
