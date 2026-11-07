#!/usr/bin/env python3
"""Verify the current client-release run and stage its schema-1 release.

\`preflight\` checks the tag, pubspec and changelog before any build starts.
\`assemble\` accepts only artifacts uploaded by this run after every check and
build passed, and writes manifest.json, receipt.json, release-notes.md and the
public packages under the stage directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import zipfile

REPOSITORY = 'Zolmid/FlClash'
REPOSITORY_ID = '1420254999'
WORKFLOW = '.github/workflows/client-release.yml'
APP_ID = 'com.zolmid.zolnit'
CORE = '8380d0e7462f061a964323e9bf3129a236fcc5d5'
ANDROID_CERT = '35a6ce68c05fd989aa65367a1cefb2e22fb02797b3c6cb1e67ce3d90a2bb6739'
DOWNLOADS = 'https://link.zolmid.com/client/downloads'
TAG = re.compile(r'v(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})\.(0|[1-9]\d{0,9})')
COMMIT = re.compile(r'[0-9a-f]{40}')
DIGEST = re.compile(r'[0-9a-f]{64}')
MEMBER = re.compile(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,199}')
KEY_LINE = re.compile(r'([a-z][a-z0-9_]*)=(.*)')
SUBMODULE_LINE = re.compile(r'([ +\-U])([0-9a-f]{40}) (\S+)(?: \(.*\))?')
SUMS_LINE = re.compile(r'([0-9a-f]{64}) [ *](?:\./)?([^/\\]+)')
MAX_ASSET_BYTES = 2 * 1024 ** 3
MAX_ARTIFACT_BYTES = 6 * 1024 ** 3
MAX_NOTES_BYTES = 32768
NOTES_BEGIN = '<!-- flclash:changelog:begin -->'
NOTES_END = '<!-- flclash:changelog:end -->'
NOTES_FILE = 'release-notes.md'
CHUNK = 1024 * 1024

TARGETS = (
    ('android', 'arm64', 'flclash-android-arm64-{run}'),
    ('linux', 'x64', 'flclash-linux-x64-{run}'),
    ('macos', 'arm64', 'flclash-macos-arm64-{run}'),
    ('macos', 'x64', 'flclash-macos-x64-{run}'),
    ('windows', 'x64', 'flclash-windows-x64-{run}'),
    ('ios', 'arm64', 'ios-project-arm64-unsigned-{run}'),
)
NOTES_ARTIFACT = 'client-release-notes-{run}'


class ReleaseError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def sha256_file(path):
    value = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(CHUNK), b''):
            value.update(chunk)
    return value.hexdigest()


def public_names(version, platform, arch):
    prefix = f'ZolNit-{version}-'
    return {
        'android': [prefix + 'android-arm64-v8a.apk'],
        'macos': [prefix + f'macos-{arch}.dmg'],
        'windows': [prefix + 'windows-x64-setup.exe', prefix + 'windows-x64.zip'],
        'linux': [prefix + 'linux-x64.AppImage', prefix + 'linux-x64.deb', prefix + 'linux-x64.zip'],
        'ios': [],
    }[platform]


class Context:
    def __init__(self, env, root):
        tag = env.get('GITHUB_REF_NAME', '')
        require(env.get('GITHUB_REPOSITORY') == REPOSITORY, 'repository is not Zolmid/FlClash')
        require(env.get('GITHUB_REPOSITORY_ID') == REPOSITORY_ID, 'repository id mismatch')
        require(env.get('GITHUB_EVENT_NAME') == 'push', 'formal releases only run from a tag push')
        require(env.get('GITHUB_REF_TYPE') == 'tag' and TAG.fullmatch(tag), f'not a formal semver tag: {tag!r}')
        require(env.get('GITHUB_REF') == f'refs/tags/{tag}', 'ref does not match the tag')
        require(env.get('GITHUB_WORKFLOW_REF') == f'{REPOSITORY}/{WORKFLOW}@refs/tags/{tag}',
                'workflow is not client-release.yml at this tag')
        sha = env.get('GITHUB_SHA', '')
        require(COMMIT.fullmatch(sha), 'GITHUB_SHA is not a commit id')
        run_id, run_number = env.get('GITHUB_RUN_ID', ''), env.get('GITHUB_RUN_NUMBER', '')
        require(run_id.isdigit() and run_number.isdigit(), 'run id and number are required')
        self.tag, self.sha, self.run_id, self.run_number = tag, sha, int(run_id), int(run_number)
        self.run_url = f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{REPOSITORY}/actions/runs/{run_id}"
        self.version, self.build = read_pubspec(Path(root) / 'pubspec.yaml', tag)


def read_pubspec(path, tag):
    found = re.findall(r'^version:[ \t]*(\S+)[ \t]*$', path.read_text(encoding='utf-8'), re.M)
    require(len(found) == 1, 'pubspec.yaml must declare exactly one version')
    match = re.fullmatch(r'(\d+\.\d+\.\d+)\+([1-9]\d{0,9})', found[0])
    require(match, f'pubspec version {found[0]!r} is not X.Y.Z+BUILD')
    version, build = match.group(1), int(match.group(2))
    require(f'v{version}' == tag, f'pubspec version {version} does not match tag {tag}')
    require(build <= 2147483647, 'build number exceeds the Android versionCode range')
    return version, build


def check_changelog(path, tag):
    data = json.loads(path.read_text(encoding='utf-8'))
    entries = [item for item in data.get('versions', []) if item.get('tag') == tag]
    require(len(entries) == 1, f'changelog.json has no single entry for {tag}; run '
            f'"dart run tool/changelog.dart release --version {tag[1:]}" and commit it before tagging')
    require(entries[0].get('prerelease') is False, f'{tag} is recorded as a prerelease')


class GitHub:
    """Read-only GitHub API access through the gh CLI, which also follows the
    artifact download redirect without forwarding the token to blob storage."""

    def __init__(self, repository=REPOSITORY):
        self.repository = repository

    def get(self, path):
        output = subprocess.run(['gh', 'api', '-H', 'Accept: application/vnd.github+json', path],
                                check=True, stdout=subprocess.PIPE).stdout
        return json.loads(output)

    def download(self, path, destination):
        with open(destination, 'xb') as handle:
            subprocess.run(['gh', 'api', path], check=True, stdout=handle)

    def tag_commit(self, tag):
        target = self.get(f'repos/{self.repository}/git/ref/tags/{tag}')
        for _ in range(4):
            obj = target.get('object') or {}
            if obj.get('type') == 'commit':
                return obj.get('sha')
            require(obj.get('type') == 'tag', f'{tag} does not point at a commit')
            target = self.get(f"repos/{self.repository}/git/tags/{obj.get('sha')}")
        raise ReleaseError(f'{tag} nests too many tag objects')

    def artifacts(self, run_id):
        records, page = [], 1
        while True:
            body = self.get(f'repos/{self.repository}/actions/runs/{run_id}/artifacts?per_page=100&page={page}')
            batch = body.get('artifacts', [])
            records.extend(batch)
            if not batch or len(records) >= int(body.get('total_count', 0)):
                return records
            page += 1


def extract(archive, directory, limit=MAX_ARTIFACT_BYTES):
    """Extract a flat artifact archive, refusing anything but plain files."""
    directory.mkdir(parents=True)
    with zipfile.ZipFile(archive) as source:
        members, names, total = source.infolist(), set(), 0
        for item in members:
            require(MEMBER.fullmatch(item.filename), f'unsafe archive member {item.filename!r}')
            require(item.filename not in names, f'duplicate archive member {item.filename}')
            require(not item.is_dir(), f'directory archive member {item.filename}')
            mode = item.external_attr >> 16
            require(stat.S_IFMT(mode) in (0, stat.S_IFREG), f'non-regular archive member {item.filename}')
            require(not item.flag_bits & 0x1, f'encrypted archive member {item.filename}')
            total += item.file_size
            require(total <= limit, 'artifact expands beyond the size limit')
            names.add(item.filename)
        for item in members:
            descriptor = os.open(directory / item.filename,
                                 os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o644)
            written = 0
            with source.open(item) as reader, os.fdopen(descriptor, 'wb') as writer:
                for chunk in iter(lambda: reader.read(CHUNK), b''):
                    written += len(chunk)
                    require(written <= item.file_size, f'{item.filename} is larger than recorded')
                    writer.write(chunk)
            require(written == item.file_size, f'{item.filename} is shorter than recorded')
    return names


def verify_sums(directory, names):
    require('SHA256SUMS' in names, 'artifact has no SHA256SUMS')
    listed = {}
    for line in (directory / 'SHA256SUMS').read_text(encoding='utf-8').splitlines():
        match = SUMS_LINE.fullmatch(line)
        require(match, f'malformed SHA256SUMS line {line!r}')
        digest, name = match.groups()
        require(name not in listed, f'SHA256SUMS lists {name} twice')
        listed[name] = digest
    require(set(listed) == names - {'SHA256SUMS'},
            f'SHA256SUMS does not cover the artifact exactly: {sorted(set(listed) ^ (names - {"SHA256SUMS"}))}')
    for name, digest in listed.items():
        require(sha256_file(directory / name) == digest, f'{name} does not match SHA256SUMS')
    return listed


def parse_provenance(text):
    fields, submodules = {}, []
    for line in text.splitlines():
        key = KEY_LINE.fullmatch(line)
        if key:
            require(key.group(1) not in fields, f'provenance repeats {key.group(1)}')
            fields[key.group(1)] = key.group(2)
            continue
        module = SUBMODULE_LINE.fullmatch(line)
        if module:
            submodules.append(module.groups())
    return fields, submodules


def check_provenance(text, context, platform, arch):
    fields, submodules = parse_provenance(text)
    expected = {
        'source_repository': REPOSITORY, 'source_commit': context.sha, 'native_ui': 'true',
        'client_bundle': 'true', 'official_release': 'true', 'run': context.run_url,
    }
    if platform == 'ios':
        expected.update(source_kind='project', workflow_repository=REPOSITORY,
                        workflow_commit=context.sha, routing_observation='false')
        for key in ('app_bundle_id', 'observer_bundle_id', 'app_group', 'distribution_channel'):
            require(key not in fields, f'iOS provenance carries {key}; observer or debug builds are not formal')
    else:
        expected.update(target=f'{platform}-{arch}', client_safe_preview='false', distribution_channel='direct',
                        client_build_env='stable', client_defines='APP_ENV=stable;ZOLNIT_DISTRIBUTION=direct')
    for key, value in expected.items():
        require(fields.get(key) == value, f'{platform}-{arch} provenance {key}={fields.get(key)!r}, expected {value!r}')
    core = [item for item in submodules if item[2] == 'core/Clash.Meta']
    require(len(core) == 1 and core[0][:2] == (' ', CORE), f'{platform}-{arch} was not built from core {CORE}')
    require(all(item[0] in ' -' for item in submodules), f'{platform}-{arch} built from a modified submodule')
    return fields


def check_android_signing(report):
    lines = report.splitlines()
    require(lines and lines[0] == 'Verifies', 'APK signature did not verify')
    require('Number of signers: 1' in lines, 'APK must have exactly one signer')
    certs = set(re.findall(r'certificate SHA-256 digest: ([0-9a-f]{64})$', report, re.M))
    require(certs == {ANDROID_CERT}, 'APK is not signed by the production certificate')
    require(any(re.fullmatch(r'Verified using v[23] scheme \(APK Signature Scheme v[23]\): true', line)
                for line in lines), 'APK lacks a v2/v3 signature')


def check_ios(directory, listed, version):
    ipas = [name for name in listed if name.endswith('.ipa')]
    require(ipas == [f'ZolNit-{version}-ios-arm64-unsigned.ipa'], f'unexpected iOS packages {ipas}')
    require('acceptance-pair.json' not in listed, 'iOS artifact is a routing observer acceptance build')
    with zipfile.ZipFile(directory / ipas[0]) as ipa:
        entries = ipa.namelist()
    require(any(re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', name) for name in entries), 'IPA has no app bundle')
    require(not any(name.endswith('embedded.mobileprovision') for name in entries), 'IPA unexpectedly carries provisioning')
    return ipas[0]


def check_record(record, context, name):
    run = record.get('workflow_run') or {}
    require(record.get('expired') is False, f'{name} has expired')
    require(run.get('id') == context.run_id, f'{name} does not belong to run {context.run_id}')
    require(run.get('head_sha') == context.sha, f'{name} was built from another commit')
    require(str(run.get('repository_id')) == REPOSITORY_ID, f'{name} belongs to another repository')
    require(str(run.get('head_repository_id', REPOSITORY_ID)) == REPOSITORY_ID, f'{name} was built from a fork')
    digest = record.get('digest') or ''
    require(re.fullmatch(r'sha256:[0-9a-f]{64}', digest), f'{name} has no artifact digest')
    return digest[7:]


def fetch_artifact(github, record, context, name, work):
    expected = check_record(record, context, name)
    archive = work / f'{record["id"]}.zip'
    github.download(f'repos/{REPOSITORY}/actions/artifacts/{record["id"]}/zip', archive)
    require(sha256_file(archive) == expected, f'{name} does not match its GitHub artifact digest')
    directory = work / name
    names = extract(archive, directory)
    archive.unlink()
    return directory, names, expected


def run_android_verifier(apksigner, apk):
    result = subprocess.run([apksigner, 'verify', '--verbose', '--print-certs', str(apk)],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    require(result.returncode == 0, 'apksigner rejected the release APK')
    check_android_signing(result.stdout)


def public_notes(raw):
    require(0 < len(raw) <= MAX_NOTES_BYTES, 'release notes are empty or exceed 32 KiB')
    text = raw.decode('utf-8').replace('\r\n', '\n')
    require('\0' not in text, 'release notes were not rendered by tool/changelog.dart')
    begin = NOTES_BEGIN + '\n'
    end = '\n' + NOTES_END
    require(text.startswith(begin) and text.count(NOTES_BEGIN) == 1 and text.count(NOTES_END) == 1,
            'release notes were not rendered by tool/changelog.dart')
    stop = text.find(end, len(begin))
    require(stop >= len(begin) and text[stop + len(end):stop + len(end) + 1] in ('', '\n'),
            'release notes were not rendered by tool/changelog.dart')
    section = text[len(begin):stop]
    require(section.count('<!--') == section.count('-->'), 'release notes contain an unclosed comment')
    visible = re.sub(r'<!--.*?-->', '', section, flags=re.S).strip()
    require('<!--' not in visible and '-->' not in visible, 'release notes contain an unclosed comment')
    require(visible, 'release notes have no visible public content')
    return visible + '\n'


def assemble(context, github, stage, env, apksigner):
    require(env.get('ZOLNIT_CI_RESULT') == 'success' and env.get('ZOLNIT_BUILDS_RESULT') == 'success',
            'standard CI and every release build must succeed first')
    require(github.tag_commit(context.tag) == context.sha, f'{context.tag} no longer points at {context.sha}')
    stage = Path(stage)
    stage.mkdir(parents=True)
    work, packages = stage / 'artifacts', stage / 'packages' / context.tag
    work.mkdir()
    packages.mkdir(parents=True)

    wanted = {template.format(run=context.run_number): (platform, arch) for platform, arch, template in TARGETS}
    notes_name = NOTES_ARTIFACT.format(run=context.run_number)
    records = {}
    for record in github.artifacts(context.run_id):
        name = record.get('name')
        if name in wanted or name == notes_name:
            require(name not in records, f'run {context.run_id} has more than one {name}')
            records[name] = record
    missing = sorted((set(wanted) | {notes_name}) - set(records))
    require(not missing, f'missing release evidence: {missing}')

    assets, receipts, evidence = [], [], []
    for name, (platform, arch) in sorted(wanted.items(), key=lambda item: item[1]):
        record = records[name]
        directory, names, outer = fetch_artifact(github, record, context, name, work)
        listed = verify_sums(directory, names)
        require('source-provenance.txt' in listed, f'{name} has no source provenance')
        check_provenance((directory / 'source-provenance.txt').read_text(encoding='utf-8'), context, platform, arch)
        item = {'artifact_name': name, 'artifact_id': record['id'], 'artifact_sha256': outer,
                'platform': platform, 'arch': arch}
        if platform == 'ios':
            ipa = check_ios(directory, listed, context.version)
            evidence.append({**item, 'kind': 'ios-unsigned-compile', 'file': ipa, 'sha256': listed[ipa],
                             'distributed': False})
            continue
        if platform == 'android':
            require('apk-signing-report.txt' in listed, 'Android artifact has no signing report')
            check_android_signing((directory / 'apk-signing-report.txt').read_text(encoding='utf-8'))
            apk = public_names(context.version, platform, arch)[0]
            require(apk in listed, 'Android artifact has no release APK')
            if apksigner:
                run_android_verifier(apksigner, directory / apk)
        for filename in public_names(context.version, platform, arch):
            require(filename in listed, f'{name} lacks {filename}')
            destination = packages / filename
            shutil.copyfile(directory / filename, destination)
            size, digest = destination.stat().st_size, sha256_file(destination)
            require(digest == listed[filename], f'{filename} changed while staging')
            require(0 < size <= MAX_ASSET_BYTES, f'{filename} size {size} is outside the distribution limit')
            assets.append({'name': filename, 'url': f'{DOWNLOADS}/{context.tag}/{filename}', 'size': size,
                           'sha256': digest})
            receipts.append({'name': filename, 'size': size, 'sha256': digest, 'platform': platform, 'arch': arch,
                             'ci_run_id': context.run_id, 'artifact_id': record['id'],
                             'artifact_sha256': outer})
        evidence.append({**item, 'kind': 'package-build', 'distributed': True})
        shutil.rmtree(directory)

    directory, names, outer = fetch_artifact(github, records[notes_name], context, notes_name, work)
    require(names == {NOTES_FILE}, f'{notes_name} must contain only {NOTES_FILE}')
    raw = (directory / NOTES_FILE).read_bytes()
    notes = public_notes(raw)
    evidence.append({'artifact_name': notes_name, 'artifact_id': records[notes_name]['id'],
                     'artifact_sha256': outer, 'kind': 'release-notes', 'sha256': hashlib.sha256(raw).hexdigest(),
                     'distributed': False})
    shutil.rmtree(work)

    assets.sort(key=lambda item: item['name'])
    receipts.sort(key=lambda item: item['name'])
    evidence.sort(key=lambda item: item['artifact_name'])
    manifest = {'schema_version': 1, 'app_id': APP_ID, 'updates_enabled': True,
                'releases': [{'tag': context.tag, 'notes': notes, 'assets': assets}]}
    receipt = {'schema_version': 1, 'repository_id': REPOSITORY_ID, 'source_sha': context.sha, 'tag': context.tag,
               'build': context.build, 'core_sha': CORE, 'ci_run_id': context.run_id, 'assets': receipts,
               'evidence': evidence,
               'checks': {'all_platform_builds': True, 'standard_ci': True, 'package_hashes': True,
                          'android_production_certificate': True, 'ios_unsigned_compile': True}}
    (stage / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False), encoding='utf-8')
    (stage / 'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False), encoding='utf-8')
    (stage / NOTES_FILE).write_text(notes, encoding='utf-8')
    return {'tag': context.tag, 'build': context.build, 'source_sha': context.sha,
            'verified_targets': len(wanted), 'public_assets': len(assets)}


def main(argv=None, env=None, github=None):
    env = os.environ if env is None else env
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('preflight')
    build = commands.add_parser('assemble')
    build.add_argument('--stage', required=True)
    build.add_argument('--apksigner')
    args = parser.parse_args(argv)
    github = github or GitHub()
    try:
        context = Context(env, args.root)
        if args.command == 'preflight':
            check_changelog(Path(args.root) / 'changelog.json', context.tag)
            require(github.tag_commit(context.tag) == context.sha, f'{context.tag} no longer points at {context.sha}')
            result = {'tag': context.tag, 'version': context.version, 'build': context.build}
            if env.get('GITHUB_OUTPUT'):
                with open(env['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
                    output.write(f'version={context.version}\nbuild={context.build}\n')
        else:
            result = assemble(context, github, args.stage, env, args.apksigner)
    except (ReleaseError, OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f'::error::{error}', file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
