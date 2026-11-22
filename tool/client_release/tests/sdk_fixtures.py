"""Minimal structural mobile binaries for missing-SDK and malformed-package tests."""
import hashlib
import io
import struct
import zlib
import zipfile


def macho_bytes(classes=b'DNSResolver\0OwnedDnsSdkBridge\0', fusion=True, cpu=0x0100000c):
    selector = b'setFusionDNSWithIPv4:IPv6:Host:Port:HealthCheckDomain:accessKeyId:accesskeySecret:\0' if fusion else b'other:\0'
    command_size = 72 + 2 * 80
    data_offset = 32 + command_size
    body = classes + selector
    header = struct.pack('<8I', 0xfeedfacf, cpu, 0, 2, 1, command_size, 0, 0)
    command = struct.pack('<II16sQQQQiiII', 0x19, command_size, b'__TEXT', 0x100000000,
                          data_offset + len(body), 0, data_offset + len(body), 5, 5, 2, 0)
    for name, offset, value in [(b'__objc_classname', data_offset, classes),
                                (b'__objc_methname', data_offset + len(classes), selector)]:
        command += struct.pack('<16s16sQQIIIIIIII', name, b'__TEXT', 0x100000000 + offset,
                               len(value), offset, 0, 0, 0, 0, 0, 0, 0)
    return header + command + body


def uleb(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    return bytes(result + bytes([value]))


def dex_bytes(defined=True, fusion=True):
    strings = [b'InitFusionDNS' if fusion else b'OtherMethod', b'Lcom/alibaba/pdns/DNSResolver;', b'V']
    data = bytearray(184)
    string_offsets = []
    for value in strings:
        string_offsets.append(len(data))
        data.extend(uleb(len(value)) + value + b'\0')
    class_data = len(data)
    code_offset = (class_data + 9 + 3) & ~3
    encoded = b'\0\0\1\0' + uleb(0) + uleb(9) + uleb(code_offset)
    assert class_data + len(encoded) <= code_offset
    data.extend(encoded)
    data.extend(b'\0' * (code_offset - len(data)))
    data.extend(struct.pack('<4HIIH', 0, 0, 0, 0, 0, 1, 0x0e))
    data[:8] = b'dex\n037\0'
    struct.pack_into('<III', data, 32, len(data), 112, 0x12345678)
    struct.pack_into('<II', data, 56, 3, 112)
    struct.pack_into('<II', data, 64, 2, 124)
    struct.pack_into('<II', data, 72, 1, 132)
    struct.pack_into('<II', data, 88, 1, 144)
    struct.pack_into('<II', data, 96, int(defined), 152 if defined else 0)
    struct.pack_into('<II', data, 104, len(data) - 184, 184)
    struct.pack_into('<3I', data, 112, *string_offsets)
    struct.pack_into('<2I', data, 124, 1, 2)
    struct.pack_into('<3I', data, 132, 2, 1, 0)
    struct.pack_into('<HHI', data, 144, 0, 0, 0)
    struct.pack_into('<8I', data, 152, 0, 1, 0xffffffff, 0, 0xffffffff, 0, class_data, 0)
    data[12:32] = hashlib.sha1(data[32:]).digest()
    struct.pack_into('<I', data, 8, zlib.adler32(data[12:]) & 0xffffffff)
    return bytes(data)


def apk_bytes(defined=True, fusion=True):
    result = io.BytesIO()
    with zipfile.ZipFile(result, 'w') as archive:
        archive.writestr('classes.dex', dex_bytes(defined=defined, fusion=fusion))
    return result.getvalue()
