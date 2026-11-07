#!/usr/bin/env python3
"""Mirror an R2-published formal release to GitHub Releases.

Runs only after the release edge reports downloads_enabled. The release is a
draft until every asset matches the verified manifest; a rerun resumes the
draft, and an existing asset with different bytes is never replaced. It is
marked latest only while the live R2 manifest still points at this tag.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request

from assemble_release import NOTES_FILE, REPOSITORY, TAG, ReleaseError, require, sha256_file

LIVE_MANIFEST = 'https://link.zolmid.com/client/releases.json'


class GitHubReleases:
    def __init__(self, repository=REPOSITORY):
        self.repository = repository

    def _api(self, args, body=None, stdout=subprocess.PIPE):
        command = ['gh', 'api', '-H', 'Accept: application/vnd.github+json', *args]
        data = None
        if body is not None:
            command += ['--input', '-']
            data = json.dumps(body).encode()
        return subprocess.run(command, input=data, stdout=stdout, check=True).stdout

    def releases(self):
        found, page = [], 1
        while True:
            batch = json.loads(self._api([f'repos/{self.repository}/releases?per_page=100&page={page}']))
            found.extend(batch)
            if len(batch) < 100:
                return found
            page += 1

    def assets(self, release_id):
        found, page = [], 1
        while True:
            batch = json.loads(self._api([f'repos/{self.repository}/releases/{release_id}/assets?per_page=100&page={page}']))
            found.extend(batch)
            if len(batch) < 100:
                return found
            page += 1

    def create(self, body):
        return json.loads(self._api(['--method', 'POST', f'repos/{self.repository}/releases'], body))

    def update(self, release_id, body):
        return json.loads(self._api(['--method', 'PATCH', f'repos/{self.repository}/releases/{release_id}'], body))

    def delete_asset(self, asset_id):
        self._api(['--method', 'DELETE', f'repos/{self.repository}/releases/assets/{asset_id}'])

    def asset_sha256(self, asset_id):
        with tempfile.NamedTemporaryFile() as handle:
            subprocess.run(['gh', 'api', '-H', 'Accept: application/octet-stream',
                            f'repos/{self.repository}/releases/assets/{asset_id}'], stdout=handle, check=True)
            handle.flush()
            return sha256_file(handle.name)

    def upload(self, tag, path):
        subprocess.run(['gh', 'release', 'upload', tag, str(path), '--repo', self.repository], check=True)


def live_manifest(opener=urllib.request.urlopen):
    request = urllib.request.Request(LIVE_MANIFEST, headers={'Accept': 'application/json', 'Cache-Control': 'no-cache'})
    with opener(request, timeout=30) as response:
        return json.loads(response.read(1024 * 1024))


def is_live(manifest, live):
    """True only while R2 serves exactly this release as the current one."""
    ours = manifest['releases'][0]
    releases = live.get('releases') if isinstance(live, dict) else None
    if live.get('updates_enabled') is not True or not isinstance(releases, list) or len(releases) != 1:
        return False
    current = releases[0]
    return current.get('tag') == ours['tag'] and current.get('assets') == ours['assets']


def matches(github, asset, expected):
    if asset.get('state') != 'uploaded' or asset.get('size') != expected['size']:
        return False
    digest = asset.get('digest')
    if digest:
        return digest == 'sha256:' + expected['sha256']
    return github.asset_sha256(asset['id']) == expected['sha256']


def mirror(stage, env, github, live):
    stage = Path(stage)
    result = json.loads((stage / 'publish-result.json').read_text(encoding='utf-8'))
    manifest = json.loads((stage / 'manifest.json').read_text(encoding='utf-8'))
    release = manifest['releases'][0]
    tag, sha = env.get('GITHUB_REF_NAME', ''), env.get('GITHUB_SHA', '')
    require(TAG.fullmatch(tag) and release['tag'] == tag and result.get('tag') == tag and result.get('source_sha') == sha,
            'publish result does not belong to this tag and commit')
    if result.get('downloads_enabled') is not True:
        require(result.get('state') == 'staged', f"unexpected release edge state {result.get('state')!r}")
        return {'tag': tag, 'github_release': 'skipped', 'reason': 'downloads disabled; assets stay private on the edge'}
    require(result.get('state') in ('published', 'notified'), f"unexpected release edge state {result.get('state')!r}")
    notes = (stage / NOTES_FILE).read_text(encoding='utf-8')
    require(notes == release['notes'], 'release notes differ from the published manifest')
    require(live.get('updates_enabled') is True, 'R2 distribution is not live; the GitHub release is left untouched')

    latest = is_live(manifest, live)
    candidates = [item for item in github.releases() if item.get('tag_name') == tag]
    require(len(candidates) <= 1, f'more than one GitHub release uses {tag}')
    title = f'ZolNit {tag[1:]}'
    if candidates:
        current = candidates[0]
        if current.get('draft'):
            changes = {key: value for key, value in {'name': title, 'body': notes}.items() if current.get(key) != value}
            if changes:
                current = github.update(current['id'], changes)
    else:
        current = github.create({'tag_name': tag, 'name': title, 'body': notes, 'draft': True,
                                 'prerelease': False, 'make_latest': 'false'})
    require(current.get('tag_name') == tag, 'GitHub returned a release for another tag')
    draft = bool(current.get('draft'))
    require(not current.get('prerelease'), f'{tag} is marked as a prerelease on GitHub')
    require(current.get('name') == title and current.get('body') == notes,
            f'GitHub release {tag} title or notes differ from the verified release')

    expected = {asset['name']: asset for asset in release['assets']}
    existing = {}
    for asset in github.assets(current['id']):
        name = asset.get('name')
        require(name in expected, f'GitHub release {tag} carries unexpected asset {name}')
        if asset.get('state') != 'uploaded' and draft:
            github.delete_asset(asset['id'])
            continue
        require(matches(github, asset, expected[name]), f'GitHub asset {name} differs from the verified package')
        existing[name] = asset
    uploaded = []
    for name in sorted(set(expected) - set(existing)):
        require(draft, f'published GitHub release {tag} is missing {name}')
        path = stage / 'packages' / tag / name
        require(sha256_file(path) == expected[name]['sha256'], f'{name} changed after verification')
        github.upload(tag, path)
        uploaded.append(name)
    final = {asset['name']: asset for asset in github.assets(current['id'])}
    require(set(final) == set(expected), 'GitHub release assets are incomplete after upload')
    for name, asset in final.items():
        require(matches(github, asset, expected[name]), f'uploaded GitHub asset {name} does not match')

    if draft:
        github.update(current['id'], {'draft': False, 'make_latest': 'true' if latest else 'false'})
    elif latest:
        github.update(current['id'], {'make_latest': 'true'})
    return {'tag': tag, 'github_release': 'published', 'was_draft': draft, 'uploaded': uploaded, 'latest': latest}


def main(argv=None, env=None, github=None, live=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--stage', required=True)
    args = parser.parse_args(argv)
    env = os.environ if env is None else env
    try:
        stage = Path(args.stage)
        published = json.loads((stage / 'publish-result.json').read_text(encoding='utf-8'))
        if live is None and published.get('downloads_enabled') is True:
            live = live_manifest()
        result = mirror(stage, env, github or GitHubReleases(), live or {})
    except (ReleaseError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'::error::{error}', file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    sys.exit(main())
