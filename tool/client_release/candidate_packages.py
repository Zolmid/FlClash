"""Inspect development packages as data. Never install or launch a payload."""
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import tempfile
import zipfile

from assemble_release import APP_ID, MAX_ARTIFACT_BYTES, MEMBER, public_names, require

if Path(__file__).with_name('sdk_verification.py').is_file():
    import sdk_verification as mobile_sdk
else:
    mobile_sdk = None

DEVELOPMENT_APK = 'FlClash-android-arm64-development.apk'
IOS_PARTS = (
    ('Payload/Runner.app/', '', None),
    ('Payload/Runner.app/PlugIns/NECore.appex/', '.NECore', 'com.apple.networkextension.packet-tunnel'),
    ('Payload/Runner.app/PlugIns/Widget.appex/', '.Widget', 'com.apple.widgetkit-extension'),
)
ARM64, X86_64 = 0x0100000c, 0x01000007


def package_names(platform, arch, version):
    if platform == 'ios':
        return [f'ZolNit-{version}-ios-arm64-unsigned.ipa']
    if platform == 'android':
        return [DEVELOPMENT_APK]
    ext = 'tar.gz' if platform == 'linux' else 'zip'
    return [*public_names(version, platform, arch), f'FlClash-{platform}-{arch}-release.{ext}']


def zip_inventory(archive):
    entries = archive.infolist()
    require(len(entries) <= 32000 and sum(e.file_size for e in entries) <= MAX_ARTIFACT_BYTES,
            'package ZIP exceeds inspection limits')
    require(all(not e.flag_bits & 1 for e in entries), 'encrypted package ZIP member')
    names = {e.filename for e in entries}
    require(len(names) == len(entries), 'duplicate package ZIP member')
    return names


def bundled_info(archive, prefix, identifier, version, build, sdk_platform):
    plist = archive.getinfo(prefix + 'Info.plist')
    require(0 < plist.file_size <= 256 * 1024, 'bundle Info.plist size out of bounds')
    info = plistlib.loads(archive.read(plist))
    require(isinstance(info, dict) and info.get('CFBundleIdentifier') == identifier, 'bundle identifier mismatch')
    require(info.get('CFBundleShortVersionString') == version and info.get('CFBundleVersion') == str(build),
            'bundle version/build mismatch')
    require(re.fullmatch(sdk_platform + r'27(?:\.[0-9]+){1,2}', str(info.get('DTSDKName'))), 'bundle SDK mismatch')
    executable = info.get('CFBundleExecutable')
    require(isinstance(executable, str) and MEMBER.fullmatch(executable), 'invalid bundle executable name')
    return info


def macho(archive, name, cpu):
    entry = archive.getinfo(name)
    with archive.open(entry) as binary:
        header = binary.read(32)
    require(len(header) == 32, 'truncated Mach-O header')
    magic, actual, _, kind, commands, size, _, _ = struct.unpack('<8I', header)
    require((magic, actual, kind) == (0xfeedfacf, cpu, 2), 'wrong Mach-O executable architecture')
    require(0 < commands <= 4096 and 8 * commands <= size <= 1024 * 1024 and 32 + size <= entry.file_size,
            'invalid Mach-O load command bounds')


def inspect_ios(path, version, build, sdk):
    with zipfile.ZipFile(path) as archive:
        names = zip_inventory(archive)
        require(not any(n.endswith('embedded.mobileprovision') for n in names), 'provisioned candidate IPA')
        bundles = {n for n in names if re.fullmatch(r'Payload/[^/]+\.app/(?:PlugIns/[^/]+\.appex/)?Info\.plist', n)}
        require(bundles == {prefix + 'Info.plist' for prefix, _, _ in IOS_PARTS}, 'wrong IPA app or extensions')
        for prefix, suffix, extension in IOS_PARTS:
            info = bundled_info(archive, prefix, APP_ID + suffix, version, build, 'iphoneos')
            require(info.get('DTPlatformName') == 'iphoneos' and info['DTSDKName'] == 'iphoneos' + sdk,
                    'IPA device SDK differs from the build')
            if extension:
                settings = info.get('NSExtension')
                require(isinstance(settings, dict) and settings.get('NSExtensionPointIdentifier') == extension,
                        'unexpected iOS extension point')
            name = prefix + info['CFBundleExecutable']
            macho(archive, name, ARM64)
            if mobile_sdk and not suffix:
                with archive.open(name) as binary:
                    mobile_sdk.verify_ios_executable(binary, archive.getinfo(name).file_size)


def elf(header, machine):
    require(len(header) >= 20 and header[:6] == b'\x7fELF\x02\x01' and
            int.from_bytes(header[18:20], 'little') == machine, 'ELF architecture mismatch')


def tool_output(command):
    with tempfile.TemporaryFile() as output:
        subprocess.run(command, stdout=output, stderr=subprocess.DEVNULL, timeout=90, check=True)
        require(output.tell() <= 2 * 1024**2, 'package metadata output exceeds inspection limit')
        output.seek(0)
        return output.read().decode('utf-8')


def inspect_android(path, version, build):
    with zipfile.ZipFile(path) as archive:
        names = zip_inventory(archive)
        require({'AndroidManifest.xml', 'classes.dex'} <= names, 'APK lacks manifest or classes')
        for lib in ('libclash.so', 'libflutter.so'):
            with archive.open('lib/arm64-v8a/' + lib) as binary:
                elf(binary.read(20), 183)
    tools = Path(os.environ['ANDROID_HOME']) / 'build-tools'
    candidates = [p for p in tools.glob('*/aapt2') if re.fullmatch(r'\d+(?:\.\d+)+', p.parent.name)]
    require(candidates, 'Android SDK build-tools/aapt2 is missing')
    aapt = max(candidates, key=lambda p: tuple(map(int, p.parent.name.split('.'))))
    lines = tool_output([aapt, 'dump', 'badging', path]).splitlines()
    package = f"package: name='{APP_ID}.debug' versionCode='{build}' versionName='{version}'"
    require(lines and (lines[0] + ' ').startswith(package + ' ') and 'application-debuggable' in lines,
            'APK debug identity, version or build mismatch')
    if mobile_sdk:
        mobile_sdk.verify_android_apk(path)


def inspect_desktop(directory, listed, platform, arch, version, build):
    packages = public_names(version, platform, arch)
    if platform == 'macos':
        with zipfile.ZipFile(directory / f'FlClash-macos-{arch}-release.zip') as archive:
            zip_inventory(archive)
            prefix = 'ZolNit.app/Contents/'
            info = bundled_info(archive, prefix, APP_ID, version, build, 'macosx')
            macho(archive, prefix + 'MacOS/' + info['CFBundleExecutable'], ARM64 if arch == 'arm64' else X86_64)
        with (directory / packages[0]).open('rb') as dmg:
            dmg.seek(-512, 2)
            require(dmg.read(4) == b'koly', 'missing DMG trailer')
    elif platform == 'linux':
        appimage, deb, portable = packages
        with (directory / appimage).open('rb') as binary:
            elf(binary.read(20), 62)
        require(tool_output(['dpkg-deb', '--showformat=${Package} ${Version} ${Architecture}', '--show', directory / deb])
                == f'zolnit {version}+{build} amd64', 'Debian package metadata mismatch')
        with zipfile.ZipFile(directory / portable) as archive:
            zip_inventory(archive)
            with archive.open('ZolNit') as binary:
                elf(binary.read(20), 62)
    else:
        installer, portable = packages
        require(listed[portable] == listed['FlClash-windows-x64-release.zip'], 'Windows portable differs from bundle')
        with zipfile.ZipFile(directory / portable) as archive:
            zip_inventory(archive)
            with archive.open('ZolNit.exe') as binary:
                dos = binary.read(64)
                require(len(dos) == 64 and dos[:2] == b'MZ', 'invalid Windows executable')
                offset = int.from_bytes(dos[60:64], 'little')
                require(64 <= offset <= 1024 * 1024, 'invalid PE offset')
                binary.seek(offset)
                require(binary.read(6) == b'PE\0\0\x64\x86', 'Windows PE architecture mismatch')
        report = (directory / 'windows-signing-report.txt').read_text(encoding='utf-8').splitlines()
        require([line for line in report if line.startswith('release_ready=')] == ['release_ready=false'],
                'Windows candidate signing report mismatch')
        with (directory / installer).open('rb') as binary:
            require(binary.read(2) == b'MZ', 'invalid Windows installer')
