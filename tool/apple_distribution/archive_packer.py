"""Deterministic, verifiable packing of an unsigned direct-distribution Xcode archive."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import plistlib
import re
import stat
from typing import List, Optional, Tuple
import zipfile

from apple_distribution import TARGET_APPEX_NAMES, TARGET_BUNDLE_IDS, validate_archive_bundle, validate_source
from device_provisioning import ProvisioningError

ZIP_DATE = (1980, 1, 1, 0, 0, 0)
MAX_ENTRIES = 8192
MAX_MEMBER_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_ZIP_BYTES = 1024 * 1024 * 1024
STRIP_DIRS = {'_CodeSignature'}
STRIP_FILES = {'embedded.mobileprovision', 'embedded.provisionprofile', 'archived-expanded-entitlements.xcent', 'CodeResources'}
STRIP_SUFFIXES = ('.mobileprovision', '.provisionprofile')
SECRET_SUFFIXES = ('.p12', '.pfx', '.p8', '.keychain', '.keychain-db')
NAME_RE = re.compile(r'^[^/\\\x00-\x1f\x7f]+$')
VERSION_RE = re.compile(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$', re.M)
CORE_PATH = 'core/Clash.Meta'
COMMIT_RE = re.compile(r'^[0-9a-f]{40}$')

Entry = Tuple[str, Optional[str], int, int]


class PackError(ProvisioningError):
    pass


def _stripped(name: str) -> bool:
    return name in STRIP_DIRS or name in STRIP_FILES or name.endswith(STRIP_SUFFIXES)


def _secret(name: str) -> bool:
    return name.lower().endswith(SECRET_SUFFIXES)


def collect_entries(archive: Path) -> List[Entry]:
    """Walk the archive, materializing relative in-archive symlinks and stripping signing material."""
    if archive.is_symlink() or not archive.is_dir() or not archive.name.endswith('.xcarchive') or not NAME_RE.fullmatch(archive.name):
        raise PackError('archive_root_invalid')
    root = os.path.realpath(archive)
    entries: List[Entry] = []
    total = [0]

    def add(entry: Entry) -> None:
        entries.append(entry)
        if len(entries) > MAX_ENTRIES:
            raise PackError('archive_entry_limit')

    def walk(real_dir: str, arc: str, ancestors: frozenset) -> None:
        add((arc + '/', None, 0o755, 0))
        for name in sorted(os.listdir(real_dir)):
            if name in ('.', '..') or not NAME_RE.fullmatch(name):
                raise PackError('archive_name_invalid')
            path = os.path.join(real_dir, name)
            info = os.lstat(path)
            target_name = name
            if stat.S_ISLNK(info.st_mode):
                if os.path.isabs(os.readlink(path)):
                    raise PackError('archive_symlink_absolute')
                path = os.path.realpath(path)
                if os.path.commonpath([root, path]) != root:
                    raise PackError('archive_symlink_escape')
                try:
                    info = os.stat(path)
                except FileNotFoundError:
                    raise PackError('archive_symlink_dangling') from None
                target_name = os.path.basename(path)
            if _secret(name) or _secret(target_name):
                raise PackError('archive_contains_private_key_material')
            if _stripped(name) or _stripped(target_name):
                continue
            child = arc + '/' + name
            if stat.S_ISDIR(info.st_mode):
                if path in ancestors:
                    raise PackError('archive_symlink_cycle')
                walk(path, child, ancestors | {path})
            elif stat.S_ISREG(info.st_mode):
                total[0] += info.st_size
                if info.st_size > MAX_MEMBER_BYTES or total[0] > MAX_TOTAL_BYTES:
                    raise PackError('archive_size_limit')
                add((child, path, 0o755 if info.st_mode & 0o111 else 0o644, info.st_size))
            else:
                raise PackError('archive_special_file')

    walk(root, archive.name, frozenset({root}))
    return entries


def _copy_member(bundle: zipfile.ZipFile, info: zipfile.ZipInfo, source: str, size: int) -> None:
    fd = os.open(source, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    with os.fdopen(fd, 'rb') as stream:
        current = os.fstat(stream.fileno())
        if not stat.S_ISREG(current.st_mode) or current.st_size != size:
            raise PackError('archive_changed_during_pack')
        written = 0
        with bundle.open(info, 'w') as output:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                written += len(block)
                if written > size:
                    raise PackError('archive_changed_during_pack')
                output.write(block)
        if written != size:
            raise PackError('archive_changed_during_pack')


def pack_archive(archive: Path, output: Path) -> dict:
    entries = collect_entries(archive)
    fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    try:
        with os.fdopen(fd, 'wb') as raw, zipfile.ZipFile(raw, 'w', zipfile.ZIP_DEFLATED) as bundle:
            for name, source, mode, size in entries:
                info = zipfile.ZipInfo(name, ZIP_DATE)
                info.create_system = 3
                if source is None:
                    info.external_attr = ((stat.S_IFDIR | mode) << 16) | 0x10
                    bundle.writestr(info, b'')
                    continue
                info.external_attr = (stat.S_IFREG | mode) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                info.file_size = size
                _copy_member(bundle, info, source, size)
        size = output.stat().st_size
        if not 1024 <= size <= MAX_ZIP_BYTES:
            raise PackError('archive_zip_size_invalid')
        digest = hashlib.sha256()
        with output.open('rb') as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(block)
    except BaseException:
        output.unlink(missing_ok=True)
        raise
    return {'archive_sha256': digest.hexdigest(), 'archive_size': size, 'entries': len(entries)}


def release_identity(source: Path, tag: str, core_sha: str, runner) -> dict:
    """Bind tag, tag commit, pubspec build, and the checked-out Core gitlink of a prepared source tree."""
    if not isinstance(core_sha, str) or not COMMIT_RE.fullmatch(core_sha):
        raise PackError('core_sha_invalid')
    resolved_tag, source_sha = validate_source(source, None, tag, runner)
    pubspec = source / 'pubspec.yaml'
    if pubspec.is_symlink() or not pubspec.is_file():
        raise PackError('source_pubspec_missing')
    matches = VERSION_RE.findall(pubspec.read_text(encoding='utf-8'))
    if len(matches) != 1 or matches[0][0] != resolved_tag[1:]:
        raise PackError('source_version_mismatch')
    build = int(matches[0][1])
    if not 1 <= build <= 2147483647:
        raise PackError('source_build_invalid')
    gitlink = runner(['git', '-C', str(source), 'rev-parse', 'HEAD:' + CORE_PATH]).stdout.strip()
    checked_out = runner(['git', '-C', str(source / CORE_PATH), 'rev-parse', 'HEAD']).stdout.strip()
    if gitlink != core_sha or checked_out != core_sha:
        raise PackError('source_core_mismatch')
    return {'tag': resolved_tag, 'source_sha': source_sha.lower(), 'build': build, 'core_sha': core_sha}


def validate_archive_release(archive: Path, tag: str, build: int) -> None:
    validate_archive_bundle(archive, distribution='release-testing')
    app = archive / 'Products' / 'Applications' / 'Runner.app'
    bundles = [('app', app), ('necore', app / 'PlugIns' / TARGET_APPEX_NAMES['necore']),
               ('widget', app / 'PlugIns' / TARGET_APPEX_NAMES['widget'])]
    for target, bundle in bundles:
        info_path = bundle / 'Info.plist'
        if bundle.is_symlink() or info_path.is_symlink() or not info_path.is_file():
            raise PackError('archive_bundle_missing_' + target)
        with info_path.open('rb') as stream:
            info = plistlib.load(stream)
        if (info.get('CFBundleIdentifier') != TARGET_BUNDLE_IDS[target]
                or info.get('CFBundleShortVersionString') != tag[1:]
                or info.get('CFBundleVersion') != str(build)):
            raise PackError('archive_version_mismatch_' + target)
