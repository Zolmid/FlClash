#!/usr/bin/env python3
"""Reassemble the four original ZIP parts; optionally restore the workspace."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

BASE = Path(__file__).resolve().parent
NAME = 'ZolNit-Migration-20261020-e5b0285.zip'
EXPECTED_SIZE = 351711445
EXPECTED_SHA256 = '203216d54f4c5d4d37722cb075709d05a7ce4970593322465ffb0e8940737d3c'
PARTS = [
    (NAME + '.001', 100663296, '80e35bbe5fe2672d9682a318551237681af1c73512dd80a71e74281fb6afefb3'),
    (NAME + '.002', 100663296, '97ac41d692579fe33bbfe59534402ba5aebec270ee472e02e0110b91b1774bc2'),
    (NAME + '.003', 100663296, '0b7f614ddaf16854c363ae2e5121de65f0d21815be09a1a7e4afc1546b4d0c79'),
    (NAME + '.004', 49721557, '270840f94daaac636b21cd2cba7900dd74ac5c307469209f6900396982650e3c'),
]


def sha256(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def verify_original(path):
    if path.stat().st_size != EXPECTED_SIZE or sha256(path) != EXPECTED_SHA256:
        raise RuntimeError('Existing ZIP does not match the migration package; it was not overwritten.')
    print('Original ZIP SHA256 OK:', EXPECTED_SHA256)


def merge(verify_only):
    archive = BASE / NAME
    if archive.exists():
        verify_original(archive)
        return archive
    for name, size, _ in PARTS:
        source = BASE / name
        if not source.is_file() or source.stat().st_size != size:
            raise RuntimeError('Missing/incomplete part: ' + name)
    descriptor, temporary_name = tempfile.mkstemp(prefix='.zolnit-merge-', dir=BASE)
    temporary = Path(temporary_name)
    try:
        whole = hashlib.sha256()
        with os.fdopen(descriptor, 'wb') as output:
            for name, _, expected in PARTS:
                current = hashlib.sha256()
                with (BASE / name).open('rb') as source:
                    for block in iter(lambda: source.read(1024 * 1024), b''):
                        current.update(block)
                        whole.update(block)
                        if not verify_only:
                            output.write(block)
                if current.hexdigest() != expected:
                    raise RuntimeError('Part checksum mismatch: ' + name)
                print('Part SHA256 OK:', name)
        if whole.hexdigest() != EXPECTED_SHA256:
            raise RuntimeError('Combined ZIP checksum mismatch')
        print('Original ZIP SHA256 OK:', EXPECTED_SHA256)
        if verify_only:
            return archive
        if archive.exists():
            raise RuntimeError('ZIP appeared during assembly; refusing to overwrite it.')
        temporary.rename(archive)
        print('Assembled:', archive)
        return archive
    finally:
        if temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verify-only', action='store_true')
    parser.add_argument('--restore', action='store_true')
    parser.add_argument('--destination', type=Path,
                        default=Path.home() / 'Developer/ZolNit-Workspace')
    args = parser.parse_args()
    if args.restore and args.verify_only:
        raise RuntimeError('Use --restore or --verify-only, not both.')
    archive = merge(args.verify_only)
    if args.verify_only:
        return
    print('You may unzip this ZIP and follow README-迁移说明.md.')
    if not args.restore:
        return
    destination = args.destination.expanduser().resolve()
    if destination.exists():
        raise RuntimeError('Destination exists; choose a new --destination. Nothing was overwritten.')
    if shutil.which('git') is None:
        raise RuntimeError('Install Git before --restore. The verified ZIP is ready.')
    extract_dir = Path(tempfile.mkdtemp(prefix='.zolnit-package-', dir=BASE))
    try:
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                target = (extract_dir / member.filename).resolve()
                if not target.is_relative_to(extract_dir.resolve()):
                    raise RuntimeError('Unsafe archive path')
            source.extractall(extract_dir)
        restore_script = extract_dir / NAME.removesuffix('.zip') / 'tools/restore.py'
        subprocess.run([sys.executable, str(restore_script), '--destination', str(destination)],
                       check=True)
    finally:
        shutil.rmtree(extract_dir)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print('Stopped:', error, file=sys.stderr)
        sys.exit(1)
