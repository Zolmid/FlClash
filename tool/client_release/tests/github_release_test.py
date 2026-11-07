import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import github_release as gr  # noqa: E402

TAG, SHA = 'v1.2.3', 'c' * 40
NOTES = '<!-- flclash:changelog:begin -->\n- fix\n<!-- flclash:changelog:end -->\n'
ENV = {'GITHUB_REF_NAME': TAG, 'GITHUB_SHA': SHA}
PACKAGES = {'ZolNit-1.2.3-android-arm64-v8a.apk': b'apk', 'ZolNit-1.2.3-macos-arm64.dmg': b'dmg',
            'ZolNit-1.2.3-linux-x64.deb': b'deb'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


class FakeReleases:
    def __init__(self, releases=None):
        self.releases_list = releases or []
        for release in self.releases_list:
            release.setdefault('name', f'ZolNit {TAG[1:]}')
        self.files, self.calls, self.next_id = {}, [], 900

    def releases(self):
        return [dict(item) for item in self.releases_list]

    def find(self, release_id):
        return next(item for item in self.releases_list if item['id'] == release_id)

    def assets(self, release_id):
        return [dict(item) for item in self.find(release_id)['assets']]

    def create(self, body):
        self.calls.append(('create', body))
        release = {'id': 77, 'tag_name': body['tag_name'], 'draft': body['draft'], 'prerelease': False,
                   'body': body['body'], 'name': body['name'], 'assets': []}
        self.releases_list.append(release)
        return dict(release)

    def update(self, release_id, body):
        self.calls.append(('update', body))
        release = self.find(release_id)
        release.update({key: value for key, value in body.items() if key in ('name', 'body', 'draft')})
        return dict(release)

    def delete_asset(self, asset_id):
        self.calls.append(('delete', asset_id))
        for release in self.releases_list:
            release['assets'] = [item for item in release['assets'] if item['id'] != asset_id]

    def asset_sha256(self, asset_id):
        self.calls.append(('download', asset_id))
        return digest(self.files[asset_id])

    def upload(self, tag, path):
        self.calls.append(('upload', path.name))
        release = next(item for item in self.releases_list if item['tag_name'] == tag)
        data = path.read_bytes()
        self.next_id += 1
        release['assets'].append({'id': self.next_id, 'name': path.name, 'state': 'uploaded', 'size': len(data),
                                  'digest': 'sha256:' + digest(data)})


def asset(name, data=None, state='uploaded', with_digest=True, asset_id=None):
    data = PACKAGES[name] if data is None else data
    return {'id': asset_id or abs(hash(name)) % 10000, 'name': name, 'state': state, 'size': len(data),
            'digest': 'sha256:' + digest(data) if with_digest else None}


class MirrorTest(unittest.TestCase):
    def setUp(self):
        self.stage = Path(tempfile.mkdtemp(prefix='zolnit-gh-release-test-'))
        self.addCleanup(shutil.rmtree, self.stage, True)
        (self.stage / 'packages' / TAG).mkdir(parents=True)
        assets = []
        for name, data in sorted(PACKAGES.items()):
            (self.stage / 'packages' / TAG / name).write_bytes(data)
            assets.append({'name': name, 'url': f'https://link.zolmid.com/client/downloads/{TAG}/{name}',
                           'size': len(data), 'sha256': digest(data)})
        self.manifest = {'schema_version': 1, 'app_id': 'com.zolmid.zolnit', 'updates_enabled': True,
                         'releases': [{'tag': TAG, 'notes': NOTES, 'assets': assets}]}
        (self.stage / 'manifest.json').write_text(json.dumps(self.manifest))
        (self.stage / 'release-notes.md').write_text(NOTES)
        self.result({'tag': TAG, 'source_sha': SHA, 'state': 'notified', 'downloads_enabled': True})

    def result(self, value):
        (self.stage / 'publish-result.json').write_text(json.dumps(value))

    def live(self, tag=TAG, enabled=True):
        live = json.loads(json.dumps(self.manifest))
        live['updates_enabled'] = enabled
        live['releases'][0]['tag'] = tag
        return live

    def test_staged_edge_result_never_touches_github(self):
        self.result({'tag': TAG, 'source_sha': SHA, 'state': 'staged', 'downloads_enabled': False})
        github = FakeReleases()
        self.assertEqual(gr.mirror(self.stage, ENV, github, {})['github_release'], 'skipped')
        self.assertEqual(github.calls, [])

    def test_new_release_is_drafted_filled_then_published_as_latest(self):
        github = FakeReleases()
        result = gr.mirror(self.stage, ENV, github, self.live())
        self.assertEqual(github.calls[0][0], 'create')
        self.assertTrue(github.calls[0][1]['draft'])
        self.assertEqual(github.calls[0][1]['body'], NOTES)
        self.assertEqual([call[1] for call in github.calls if call[0] == 'upload'], sorted(PACKAGES))
        self.assertEqual(github.calls[-1], ('update', {'draft': False, 'make_latest': 'true'}))
        self.assertTrue(result['latest'])

    def test_old_rerun_is_never_marked_latest(self):
        github = FakeReleases()
        gr.mirror(self.stage, ENV, github, self.live(tag='v1.2.4'))
        self.assertEqual(github.calls[-1], ('update', {'draft': False, 'make_latest': 'false'}))

    def test_disabled_live_manifest_leaves_github_untouched(self):
        github = FakeReleases()
        with self.assertRaises(gr.ReleaseError):
            gr.mirror(self.stage, ENV, github, self.live(enabled=False))
        self.assertEqual(github.calls, [])

    def test_interrupted_draft_resumes_without_reuploading_good_assets(self):
        apk, dmg = 'ZolNit-1.2.3-android-arm64-v8a.apk', 'ZolNit-1.2.3-macos-arm64.dmg'
        draft = {'id': 5, 'tag_name': TAG, 'draft': True, 'prerelease': False, 'body': 'stale', 'name': 'stale',
                 'assets': [asset(apk, asset_id=1), asset(dmg, data=b'dm', state='starter', asset_id=2)]}
        github = FakeReleases([draft])
        gr.mirror(self.stage, ENV, github, self.live())
        uploads = [call[1] for call in github.calls if call[0] == 'upload']
        self.assertEqual(uploads, ['ZolNit-1.2.3-linux-x64.deb', dmg])
        self.assertIn(('delete', 2), github.calls)
        self.assertIn(('update', {'name': f'ZolNit {TAG[1:]}', 'body': NOTES}), github.calls)
        self.assertEqual(github.calls[-1], ('update', {'draft': False, 'make_latest': 'true'}))

    def test_differing_bytes_are_never_clobbered(self):
        apk = 'ZolNit-1.2.3-android-arm64-v8a.apk'
        for release in ({'draft': True}, {'draft': False}):
            github = FakeReleases([{'id': 5, 'tag_name': TAG, 'prerelease': False, 'body': NOTES,
                                    'assets': [asset(apk, data=b'other', asset_id=1)], **release}])
            with self.assertRaises(gr.ReleaseError):
                gr.mirror(self.stage, ENV, github, self.live())
            self.assertFalse([call for call in github.calls if call[0] in ('upload', 'delete') or
                              (call[0] == 'update' and 'draft' in call[1])])

    def test_digestless_asset_is_hashed_before_it_is_trusted(self):
        names = sorted(PACKAGES)
        assets = [asset(name, asset_id=index + 1, with_digest=False) for index, name in enumerate(names)]
        github = FakeReleases([{'id': 5, 'tag_name': TAG, 'draft': False, 'prerelease': False, 'body': NOTES,
                                'assets': assets}])
        github.files = {index + 1: PACKAGES[name] for index, name in enumerate(names)}
        result = gr.mirror(self.stage, ENV, github, self.live())
        self.assertEqual(result['uploaded'], [])
        self.assertIn(('download', 1), github.calls)
        self.assertEqual(github.calls[-1], ('update', {'make_latest': 'true'}))

    def test_published_release_must_already_be_complete(self):
        github = FakeReleases([{'id': 5, 'tag_name': TAG, 'draft': False, 'prerelease': False, 'body': NOTES,
                                'assets': [asset('ZolNit-1.2.3-linux-x64.deb', asset_id=1)]}])
        with self.assertRaises(gr.ReleaseError):
            gr.mirror(self.stage, ENV, github, self.live())
        self.assertFalse([call for call in github.calls if call[0] == 'upload'])

    def test_published_release_title_and_notes_must_match(self):
        for field, value in (('name', 'wrong title'), ('body', 'stale notes')):
            release = {'id': 5, 'tag_name': TAG, 'draft': False, 'prerelease': False, 'body': NOTES,
                       'name': f'ZolNit {TAG[1:]}', 'assets': [asset(name) for name in PACKAGES]}
            release[field] = value
            github = FakeReleases([release])
            with self.assertRaises(gr.ReleaseError):
                gr.mirror(self.stage, ENV, github, self.live())
            self.assertEqual(github.calls, [])

    def test_unexpected_assets_or_duplicate_releases_stop_the_mirror(self):
        extra = {'id': 9, 'name': 'notes.txt', 'state': 'uploaded', 'size': 1, 'digest': 'sha256:' + '0' * 64}
        github = FakeReleases([{'id': 5, 'tag_name': TAG, 'draft': True, 'prerelease': False, 'body': NOTES,
                                'assets': [extra]}])
        with self.assertRaises(gr.ReleaseError):
            gr.mirror(self.stage, ENV, github, self.live())
        twice = [{'id': n, 'tag_name': TAG, 'draft': True, 'prerelease': False, 'body': NOTES, 'assets': []} for n in (1, 2)]
        with self.assertRaises(gr.ReleaseError):
            gr.mirror(self.stage, ENV, FakeReleases(twice), self.live())

    def test_result_from_another_commit_is_rejected(self):
        self.result({'tag': TAG, 'source_sha': 'd' * 40, 'state': 'notified', 'downloads_enabled': True})
        with self.assertRaises(gr.ReleaseError):
            gr.mirror(self.stage, ENV, FakeReleases(), self.live())

    def test_notice_pending_still_publishes(self):
        self.result({'tag': TAG, 'source_sha': SHA, 'state': 'published', 'downloads_enabled': True, 'notice_pending': True})
        github = FakeReleases()
        self.assertEqual(gr.mirror(self.stage, ENV, github, self.live())['github_release'], 'published')


class LiveManifestTest(unittest.TestCase):
    def test_request_identifies_the_publisher(self):
        sent = {}

        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

            def read(self, limit):
                sent['limit'] = limit
                return b'{"tag": "v1.2.3"}'

        def opener(request, timeout):
            sent.update(url=request.full_url, timeout=timeout, headers=dict(request.header_items()))
            return Response()

        self.assertEqual(gr.live_manifest(opener), {'tag': 'v1.2.3'})
        self.assertEqual(sent['url'], 'https://link.zolmid.com/client/releases.json')
        self.assertEqual(sent['timeout'], 30)
        self.assertEqual(sent['limit'], 1024 * 1024)
        self.assertEqual(sent['headers'], {'User-agent': 'ZolNit/ReleasePublisher', 'Accept': 'application/json',
                                           'Cache-control': 'no-cache'})


if __name__ == '__main__':
    unittest.main()
