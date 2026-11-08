import hashlib
import io
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prefetch_appimage_runtime as par  # noqa: E402
import prefetch_gradle as pg  # noqa: E402


def build_zip_bytes(entries: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in entries.items():
            archive.writestr(name, content)
    return buffer.getvalue()


class PrefetchGradleTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='zolnit-gradle-prefetch-test-'))
        self.addCleanup(shutil.rmtree, self.root, True)
        self.gradle_home = self.root / 'gradle-home'
        self.wrapper_props = self.root / 'gradle-wrapper.properties'
        self.write_wrapper_props()
        self.valid_bytes = build_zip_bytes({
            f'gradle-{pg.EXPECTED_VERSION}/bin/gradle': b'gradle-launcher',
            f'gradle-{pg.EXPECTED_VERSION}/lib/gradle-core.jar': b'jar-bytes',
        })
        self.valid_sha = hashlib.sha256(self.valid_bytes).hexdigest()
        self.valid_size = len(self.valid_bytes)

    def write_wrapper_props(self, url: str = r'https\://services.gradle.org/distributions/gradle-9.8.0-all.zip',
                            extra: str = '') -> None:
        content = (
            'distributionBase=GRADLE_USER_HOME\n'
            'distributionPath=wrapper/dists\n'
            'zipStoreBase=GRADLE_USER_HOME\n'
            'zipStorePath=wrapper/dists\n'
            f'distributionUrl={url}\n'
            f'{extra}'
        )
        self.wrapper_props.write_text(content, encoding='utf-8')

    def test_wrapper_url_hash_matches_gradle_path_assembler(self):
        self.assertEqual(
            pg.wrapper_url_hash('https://services.gradle.org/distributions/gradle-9.8.0-all.zip'),
            '619e6l8zt76uzaekhqdol0b60',
        )
        repo_wrapper = Path(__file__).resolve().parents[3] / 'android/gradle/wrapper/gradle-wrapper.properties'
        props = pg.parse_wrapper_properties(repo_wrapper)
        self.assertEqual(pg.verify_wrapper_contract(props), pg.EXPECTED_WRAPPER_URL)

    def test_fixture_prefetch_populates_expected_wrapper_cache_and_reuses_valid_cache(self):
        fixture = self.root / 'fixture.zip'
        fixture.write_bytes(self.valid_bytes)
        result = pg.prefetch_gradle(
            wrapper_properties=self.wrapper_props,
            gradle_user_home=self.gradle_home,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
            install_kotlin_mirror=True,
        )
        expected_zip = (
            self.gradle_home
            / 'wrapper/dists/gradle-9.8.0-all/619e6l8zt76uzaekhqdol0b60/gradle-9.8.0-all.zip'
        )
        expected_init = self.gradle_home / 'init.d' / pg.KOTLIN_COMPILER_INIT_SCRIPT_NAME
        self.assertEqual(result['status'], 'prefetched')
        self.assertEqual(Path(result['zip']), expected_zip)
        self.assertEqual(Path(result['kotlin_compiler_mirror_init']), expected_init)
        self.assertTrue(expected_zip.is_file())
        self.assertTrue(expected_init.is_file())
        init_text = expected_init.read_text(encoding='utf-8')
        self.assertIn(pg.GOOGLE_MAVEN_CENTRAL_MIRROR_URL, init_text)
        self.assertIn('includeModule("org.jetbrains.kotlin", "kotlin-compiler-embeddable")', init_text)
        self.assertEqual(expected_zip.read_bytes(), self.valid_bytes)

        fixture.unlink()
        expected_init.unlink()
        cached = pg.prefetch_gradle(
            wrapper_properties=self.wrapper_props,
            gradle_user_home=self.gradle_home,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
            install_kotlin_mirror=True,
        )
        self.assertEqual(cached['status'], 'cached')
        self.assertTrue(expected_init.is_file())

    def test_wrong_sha_or_size_is_rejected_without_polluting_cache(self):
        fixture = self.root / 'bad.zip'
        fixture.write_bytes(self.valid_bytes)
        target_zip = (
            self.gradle_home
            / 'wrapper/dists/gradle-9.8.0-all/619e6l8zt76uzaekhqdol0b60/gradle-9.8.0-all.zip'
        )
        with self.assertRaises(pg.PrefetchError):
            pg.prefetch_gradle(
                wrapper_properties=self.wrapper_props,
                gradle_user_home=self.gradle_home,
                fixture=fixture,
                expected_size=self.valid_size,
                expected_sha256='0' * 64,
            )
        self.assertFalse(target_zip.exists())

        with self.assertRaises(pg.PrefetchError):
            pg.prefetch_gradle(
                wrapper_properties=self.wrapper_props,
                gradle_user_home=self.gradle_home,
                fixture=fixture,
                expected_size=self.valid_size + 1,
                expected_sha256=self.valid_sha,
            )
        self.assertFalse(target_zip.exists())

    def test_corrupted_cached_zip_is_replaced_and_stale_unpack_cleaned(self):
        dist_dir = self.gradle_home / 'wrapper/dists/gradle-9.8.0-all/619e6l8zt76uzaekhqdol0b60'
        stale_unpack = dist_dir / 'gradle-9.8.0'
        stale_unpack.mkdir(parents=True)
        (stale_unpack / 'stale.txt').write_text('stale', encoding='utf-8')
        target_zip = dist_dir / 'gradle-9.8.0-all.zip'
        ok_marker = dist_dir / 'gradle-9.8.0-all.zip.ok'
        target_zip.write_bytes(b'corrupted-zip-content')
        ok_marker.write_text('', encoding='utf-8')

        fixture = self.root / 'good.zip'
        fixture.write_bytes(self.valid_bytes)
        result = pg.prefetch_gradle(
            wrapper_properties=self.wrapper_props,
            gradle_user_home=self.gradle_home,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
        )
        self.assertEqual(result['status'], 'prefetched')
        self.assertEqual(target_zip.read_bytes(), self.valid_bytes)
        self.assertFalse(ok_marker.exists())
        self.assertFalse(stale_unpack.exists())

    def test_rejects_version_drift_or_unofficial_sources(self):
        self.write_wrapper_props(url=r'https\://services.gradle.org/distributions/gradle-9.7.0-all.zip')
        fixture = self.root / 'good.zip'
        fixture.write_bytes(self.valid_bytes)
        with self.assertRaises(pg.PrefetchError):
            pg.prefetch_gradle(
                wrapper_properties=self.wrapper_props,
                gradle_user_home=self.gradle_home,
                fixture=fixture,
                expected_size=self.valid_size,
                expected_sha256=self.valid_sha,
            )

        self.write_wrapper_props()
        for bad_url in (
            'https://example.com/gradle-9.8.0-all.zip',
            'http://api.github.com/repos/gradle/gradle-distributions/releases/assets/586068849',
            'https://api.github.com/repos/evil/gradle-distributions/releases/assets/586068849',
        ):
            with self.assertRaises(pg.PrefetchError):
                pg.prefetch_gradle(
                    wrapper_properties=self.wrapper_props,
                    gradle_user_home=self.gradle_home,
                    api_url=bad_url,
                    expected_size=self.valid_size,
                    expected_sha256=self.valid_sha,
                )

    def test_rejects_unsafe_zip_paths(self):
        unsafe_bytes = build_zip_bytes({
            '../evil.sh': b'boom',
            f'gradle-{pg.EXPECTED_VERSION}/bin/gradle': b'gradle',
        })
        fixture = self.root / 'unsafe.zip'
        fixture.write_bytes(unsafe_bytes)
        with self.assertRaises(pg.PrefetchError):
            pg.prefetch_gradle(
                wrapper_properties=self.wrapper_props,
                gradle_user_home=self.gradle_home,
                fixture=fixture,
                expected_size=len(unsafe_bytes),
                expected_sha256=hashlib.sha256(unsafe_bytes).hexdigest(),
            )

    def test_cross_origin_redirect_strips_authorization_header(self):
        seen_requests = []
        redirect_handler = pg._StripAuthRedirectHandler()
        initial = urllib.request.Request(
            pg.EXPECTED_ASSET_API_URL,
            headers={
                'Accept': 'application/octet-stream',
                'Authorization': 'Bearer secret-token-value',
                'User-Agent': pg.USER_AGENT,
            },
        )
        redirected = redirect_handler.redirect_request(
            initial,
            None,
            302,
            'Found',
            {},
            'https://objects.githubusercontent.com/github-production-release-asset/586068849',
        )
        self.assertIsNotNone(redirected)
        header_keys = {k.lower() for k in redirected.headers} | {k.lower() for k in redirected.unredirected_hdrs}
        self.assertNotIn('authorization', header_keys)

        with self.assertRaises(pg.PrefetchError):
            redirect_handler.redirect_request(
                initial,
                None,
                302,
                'Found',
                {},
                'https://untrusted.example.com/gradle-9.8.0-all.zip',
            )

        class FakeResponse(io.BytesIO):
            def __enter__(self):
                return self

            def __exit__(self, *exc):
                self.close()
                return False

            def geturl(self):
                return 'https://objects.githubusercontent.com/github-production-release-asset/586068849'

        class FakeOpener:
            def open(self, request, timeout=60):
                seen_requests.append((request.full_url, dict(request.header_items()), timeout))
                return FakeResponse(self_outer.valid_bytes)

        self_outer = self
        result = pg.prefetch_gradle(
            wrapper_properties=self.wrapper_props,
            gradle_user_home=self.gradle_home,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
            env={'GH_TOKEN': 'tok_test_only'},
            opener=FakeOpener(),
        )
        self.assertEqual(result['status'], 'prefetched')
        self.assertEqual(len(seen_requests), 1)
        self.assertEqual(seen_requests[0][0], pg.EXPECTED_ASSET_API_URL)
        self.assertEqual(seen_requests[0][1].get('Authorization'), 'Bearer tok_test_only')

    def test_cli_returns_nonzero_on_failure_and_zero_on_valid_fixture(self):
        missing = self.root / 'missing.zip'
        code = pg.main([
            '--wrapper-properties', str(self.wrapper_props),
            '--gradle-user-home', str(self.gradle_home),
            '--fixture', str(missing),
        ], env={})
        self.assertEqual(code, 1)

        bad_fixture = self.root / 'bad-size.zip'
        bad_fixture.write_bytes(self.valid_bytes)
        code_mismatch = pg.main([
            '--wrapper-properties', str(self.wrapper_props),
            '--gradle-user-home', str(self.gradle_home),
            '--fixture', str(bad_fixture),
        ], env={})
        self.assertEqual(code_mismatch, 1)


class PrefetchAppImageRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='zolnit-appimage-prefetch-test-'))
        self.addCleanup(shutil.rmtree, self.root, True)
        self.valid_bytes = b'\x7fELF' + b'runtime-payload-x86_64'
        self.valid_sha = hashlib.sha256(self.valid_bytes).hexdigest()
        self.valid_size = len(self.valid_bytes)

    def test_fixture_and_cache_reuse_and_corruption_recovery(self):
        fixture = self.root / 'fixture-runtime'
        fixture.write_bytes(self.valid_bytes)
        target = self.root / 'out/runtime-x86_64'
        result = par.prefetch_appimage_runtime(
            output=target,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
        )
        self.assertEqual(result['status'], 'prefetched')
        self.assertEqual(target.read_bytes(), self.valid_bytes)

        fixture.unlink()
        cached = par.prefetch_appimage_runtime(
            output=target,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
        )
        self.assertEqual(cached['status'], 'cached')

        target.write_bytes(b'corrupted')
        fixture.write_bytes(self.valid_bytes)
        recovered = par.prefetch_appimage_runtime(
            output=target,
            fixture=fixture,
            expected_size=self.valid_size,
            expected_sha256=self.valid_sha,
        )
        self.assertEqual(recovered['status'], 'prefetched')
        self.assertEqual(target.read_bytes(), self.valid_bytes)

    def test_rejects_non_elf_wrong_hash_or_untrusted_url(self):
        non_elf = self.root / 'non-elf'
        non_elf.write_bytes(b'NOPE' + b'123456')
        target = self.root / 'out/runtime-x86_64'
        with self.assertRaises(pg.PrefetchError):
            par.prefetch_appimage_runtime(
                output=target,
                fixture=non_elf,
                expected_size=len(non_elf.read_bytes()),
                expected_sha256=hashlib.sha256(non_elf.read_bytes()).hexdigest(),
            )
        self.assertFalse(target.exists())

        with self.assertRaises(pg.PrefetchError):
            par.prefetch_appimage_runtime(
                output=target,
                api_url='https://api.github.com/repos/evil/type2-runtime/releases/assets/326011592',
                expected_size=self.valid_size,
                expected_sha256=self.valid_sha,
            )


if __name__ == '__main__':
    unittest.main()
