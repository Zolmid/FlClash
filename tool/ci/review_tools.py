"""Install the pinned review binaries into a caller-owned tools directory."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile


# Each checksum covers the upstream release asset, before extraction.
TOOLS = {
    'actionlint': ('rhysd/actionlint', 'v1.7.12', {
        ('Linux', 'x86_64'): ('actionlint_1.7.12_linux_amd64.tar.gz', '8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8'),
        ('Darwin', 'arm64'): ('actionlint_1.7.12_darwin_arm64.tar.gz', 'aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f'),
    }),
    'lychee': ('lycheeverse/lychee', 'lychee-v0.24.2', {
        ('Linux', 'x86_64'): ('lychee-x86_64-unknown-linux-musl.tar.gz', '73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5'),
        ('Darwin', 'arm64'): ('lychee-aarch64-apple-darwin.tar.gz', 'c9d3740ea2d891854d37116c9fba840f37b6e7c89d330e7db84ac333631c4977'),
    }),
    'shellcheck': ('koalaman/shellcheck', 'v0.11.0', {
        ('Linux', 'x86_64'): ('shellcheck-v0.11.0.linux.x86_64.tar.xz', '8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198'),
        ('Darwin', 'arm64'): ('shellcheck-v0.11.0.darwin.aarch64.tar.xz', '56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79'),
    }),
    'osv-scanner': ('google/osv-scanner', 'v2.7.1', {
        ('Linux', 'x86_64'): ('osv-scanner_linux_amd64', 'fb7dab19a8bd9bbe5c3189f09d4b7ee1820c9553a23bac202648a56efd2f6ee8'),
        ('Darwin', 'arm64'): ('osv-scanner_darwin_arm64', 'b22c02877a811c8f78956e8643efa554932b7378f590d13f8e97d4e9448a29f3'),
    }),
}


def install(name, directory):
    repository, version, platforms = TOOLS[name]
    host = platform.system(), platform.machine()
    if host not in platforms:
        raise SystemExit(f'{name}: no pinned binary for {host}')
    asset, expected = platforms[host]
    url = f'https://github.com/{repository}/releases/download/{version}/{asset}'
    directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=directory) as scratch:
        asset_file = Path(scratch) / 'download'
        subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                        '--proto', '=https', '--proto-redir', '=https', '--retry', '2',
                        '--max-time', '120', '--max-filesize', str(256 << 20),
                        '--output', str(asset_file), url], check=True, timeout=390)
        digest = hashlib.sha256()
        with asset_file.open('rb') as stream:
            for block in iter(lambda: stream.read(1 << 20), b''):
                digest.update(block)
        if digest.hexdigest() != expected:
            raise SystemExit(f'{name}: release asset SHA-256 mismatch')
        binary = asset_file
        if '.tar.' in asset:
            binary = Path(scratch) / name
            with tarfile.open(asset_file) as archive:
                member, = [m for m in archive if m.isfile() and Path(m.name).name == name]
                with archive.extractfile(member) as src, binary.open('xb') as dst:
                    shutil.copyfileobj(src, dst)
        binary.chmod(0o755)
        os.replace(binary, directory / name)
    print(f'{name} {version} verified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bin-dir', type=Path, required=True)
    parser.add_argument('tools', nargs='+', choices=TOOLS)
    args = parser.parse_args()
    for tool in args.tools:
        install(tool, args.bin_dir)
