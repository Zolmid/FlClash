import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_installer.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_client.dart';
import 'package:fl_clash/common/constant.dart' show repository;
import 'package:test/test.dart';

const _hash =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _name = 'FlClash-0.9.4-android-arm64-v8a.apk';
const _url = 'https://github.com/$repository/releases/download/v0.9.4/$_name';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

class _InsecureOverrides extends HttpOverrides {
  int calls = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    calls++;
    return super.createHttpClient(context)
      ..badCertificateCallback = (certificate, host, port) => true;
  }
}

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

AppUpdateClient _client(
  FutureOr<ResponseBody> Function(RequestOptions) respond,
) {
  final client = AppUpdateClient(
    dio: Dio()..httpClientAdapter = _Adapter(respond),
  );
  addTearDown(client.close);
  return client;
}

void main() {
  test(
    'rejects an untrusted TLS server even when the global app override accepts it',
    () async {
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/update_tls_cert.pem')
        ..usePrivateKey('test/fixtures/update_tls_key.pem');
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response
          ..write('abc')
          ..close();
      }, onError: (Object error) {});
      final directory = await Directory.systemTemp.createTemp(
        'flclash-update-tls-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final url = Uri.parse('https://127.0.0.1:${server.port}/package');
      final overrides = _InsecureOverrides();
      await HttpOverrides.runWithHttpOverrides(() async {
        final ambient = HttpClient();
        final response = await (await ambient.getUrl(url)).close();
        expect(await response.transform(utf8.decoder).join(), 'abc');
        ambient.close(force: true);
        final callsBefore = overrides.calls;
        final client = AppUpdateClient();
        addTearDown(client.close);
        await expectLater(
          client.downloadFile(
            url.toString(),
            '${directory.path}/package',
            retries: 0,
          ),
          throwsA(isA<DioException>()),
        );
        expect(overrides.calls, callsBefore);
      }, overrides);
    },
  );

  group('release source', () {
    test('a repository without a formal release has no update', () async {
      final client = _client((_) => ResponseBody.fromString('', 404));
      expect(await client.checkForUpdate(currentVersion: '0.9.0'), isNull);
    });

    test('uses the official API digest without querying a manifest', () async {
      final requests = <Uri>[];
      final client = _client((options) {
        requests.add(options.uri);
        return _json({
          'tag_name': 'v0.9.4',
          'body': 'notes',
          'assets': [
            {
              'name': _name,
              'browser_download_url': _url,
              'size': 3,
              'digest': 'sha256:$_hash',
            },
          ],
        });
      });
      final release = await client.checkForUpdate(
        currentVersion: '0.9.4-pre.1',
      );
      expect(release?.assets.single.sha256, _hash);
      expect(
        requests.single.toString(),
        'https://api.github.com/repos/$repository/releases/latest',
      );
      expect(
        release?.releaseUri.toString(),
        'https://github.com/$repository/releases/tag/v0.9.4',
      );
    });

    test('a release without a digest remains a browser update', () async {
      var requests = 0;
      final client = _client((_) {
        requests++;
        return _json({
          'tag_name': 'v0.9.4',
          'assets': [
            {'name': _name, 'browser_download_url': _url, 'size': 3},
          ],
        });
      });
      final release = (await client.latestRelease())!;
      expect(release.assets, isEmpty);
      expect(requests, 1);
      expect(browserDownloadUri(null, release: release), release.releaseUri);
    });

    test(
      'uses the same repository manifest only when the API is unavailable',
      () async {
        final requests = <String>[];
        final client = _client((options) {
          requests.add(options.uri.toString());
          if (options.uri.host == 'api.github.com') {
            return ResponseBody.fromString('{}', 403);
          }
          return _json({
            'tag': 'v0.9.4',
            'assets': [
              {'name': _name, 'url': _url, 'size': 3, 'sha256': _hash},
            ],
          });
        });
        expect((await client.latestRelease())!.assets.single.url, _url);
        expect(
          requests.last,
          'https://github.com/$repository/releases/latest/download/version.json',
        );
      },
    );

    test('redirect fallback refuses a different repository', () async {
      final client = _client((options) {
        if (options.uri.path.endsWith('/version.json')) {
          return ResponseBody.fromString('', 404);
        }
        if (options.uri.host == 'api.github.com') {
          return ResponseBody.fromString('', 403);
        }
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            HttpHeaders.locationHeader: [
              'https://github.com/someone/FlClash/releases/tag/v0.9.4',
            ],
          },
        );
      });
      await expectLater(client.latestRelease(), throwsFormatException);
    });

    test('keeps the typed final network error', () async {
      final client = _client((_) => ResponseBody.fromString('', 503));
      await expectLater(
        client.latestRelease(),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            503,
          ),
        ),
      );
    });
  });

  group('verified staging', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('flclash-installer-');
    });

    tearDown(() => directory.delete(recursive: true));

    AppUpdatePlan plan({String hash = _hash, int size = 3}) => AppUpdatePlan(
      target: const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
      asset: ReleaseAsset(name: _name, url: _url, size: size, sha256: hash),
    );

    test(
      'publishes only the matching size and hash in release-specific staging',
      () async {
        final client = _client(
          (_) => ResponseBody.fromBytes(
            utf8.encode('abc'),
            200,
            headers: {
              HttpHeaders.contentLengthHeader: ['3'],
            },
          ),
        );
        final installer = AppInstaller(
          client: client,
          tempDirectory: () async => directory,
        );
        final file = await installer.download(plan());
        expect(
          file.path,
          contains('app-updates${Platform.pathSeparator}v0.9.4-$_hash'),
        );
        expect(await file.readAsString(), 'abc');
        expect(File('${file.path}.part').existsSync(), isFalse);
      },
    );

    test(
      'never promotes a wrong size or hash and deletes only its own partial',
      () async {
        final client = _client(
          (_) => ResponseBody.fromBytes(
            utf8.encode('abc'),
            200,
            headers: {
              HttpHeaders.contentLengthHeader: ['3'],
            },
          ),
        );
        final installer = AppInstaller(
          client: client,
          tempDirectory: () async => directory,
        );
        final unrelated = File('${directory.path}/unrelated.part');
        await unrelated.writeAsString('keep');
        for (final invalid in [
          plan(size: 4),
          plan(
            hash:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        ]) {
          await expectLater(
            installer.download(invalid),
            throwsA(
              isA<UpdaterException>().having(
                (error) => error.reason,
                'reason',
                UpdaterFailureReason.checksumMismatch,
              ),
            ),
          );
        }
        final entries = await directory
            .list(recursive: true)
            .where((entry) => entry is File)
            .toList();
        expect(entries.map((entry) => entry.path), [unrelated.path]);
      },
    );

    for (final declaredLength in [2, 4]) {
      test(
        'rejects Content-Length $declaredLength against the declared package size before promotion',
        () async {
          var requests = 0;
          var verified = false;
          final client = _client((_) {
            requests++;
            return ResponseBody.fromBytes(
              utf8.encode('abc'),
              200,
              headers: {
                HttpHeaders.contentLengthHeader: ['$declaredLength'],
              },
            );
          });
          final target = '${directory.path}/package';
          await expectLater(
            client.downloadFile(
              _url,
              target,
              expectedSize: 3,
              verify: (_) async {
                verified = true;
              },
            ),
            throwsA(isA<UpdatePackageSizeException>()),
          );
          expect(requests, 1);
          expect(verified, isFalse);
          expect(File(target).existsSync(), isFalse);
          expect(File('$target.part').existsSync(), isFalse);
        },
      );
    }

    for (final declaresSize in [false, true]) {
      test(
        'bounds streamed bytes before writing beyond the package size, with Content-Length=$declaresSize',
        () async {
          var requests = 0;
          var verified = false;
          final progress = <int>[];
          final client = _client((_) {
            requests++;
            return ResponseBody(
              Stream.fromIterable([
                Uint8List.fromList([1, 2]),
                Uint8List.fromList([3, 4]),
              ]),
              200,
              headers: {
                if (declaresSize) HttpHeaders.contentLengthHeader: ['3'],
              },
            );
          });
          final target = '${directory.path}/package';
          await expectLater(
            client.downloadFile(
              _url,
              target,
              expectedSize: 3,
              onReceiveProgress: (received, _) => progress.add(received),
              verify: (_) async {
                verified = true;
              },
            ),
            throwsA(isA<UpdatePackageSizeException>()),
          );
          expect(requests, 1);
          expect(verified, isFalse);
          expect(progress, [2]);
          expect(File(target).existsSync(), isFalse);
          expect(File('$target.part').existsSync(), isFalse);
        },
      );
    }

    test('refuses an invalid size before issuing a download request', () async {
      var requests = 0;
      final client = _client((_) {
        requests++;
        return ResponseBody.fromBytes([], 200);
      });
      for (final size in [0, -1, maxUpdatePackageBytes + 1]) {
        await expectLater(
          client.downloadFile(
            _url,
            '${directory.path}/package',
            expectedSize: size,
          ),
          throwsArgumentError,
        );
      }
      expect(requests, 0);
    });

    test(
      'rejects an incompatible Content-Range total without promoting an existing partial',
      () async {
        final target = '${directory.path}/package';
        await File('$target.part').writeAsString('abc');
        final client = _client((options) {
          expect(options.headers[HttpHeaders.rangeHeader], 'bytes=3-');
          return ResponseBody.fromBytes(
            [4, 5, 6, 7],
            206,
            headers: {
              HttpHeaders.contentRangeHeader: ['bytes 3-6/7'],
              HttpHeaders.contentLengthHeader: ['4'],
            },
          );
        });
        await expectLater(
          client.downloadFile(_url, target, expectedSize: 6),
          throwsA(isA<UpdatePackageSizeException>()),
        );
        expect(File(target).existsSync(), isFalse);
        expect(File('$target.part').existsSync(), isFalse);
      },
    );

    test(
      'does not promote a complete server range shorter than the expected package',
      () async {
        final target = '${directory.path}/package';
        await File('$target.part').writeAsString('abc');
        final client = _client(
          (_) => ResponseBody.fromBytes(
            [],
            416,
            headers: {
              HttpHeaders.contentRangeHeader: ['bytes */3'],
            },
          ),
        );
        await expectLater(
          client.downloadFile(_url, target, expectedSize: 4),
          throwsA(isA<UpdatePackageSizeException>()),
        );
        expect(File(target).existsSync(), isFalse);
        expect(File('$target.part').existsSync(), isFalse);
      },
    );

    test(
      'serializes download, hash and installer operations across instances',
      () async {
        final entered = Completer<void>();
        final complete = Completer<ResponseBody>();
        final client = _client((_) {
          entered.complete();
          return complete.future;
        });
        final installer = AppInstaller(
          client: client,
          tempDirectory: () async => directory,
        );
        final download = installer.download(plan());
        await entered.future;
        await expectLater(
          const AppInstaller().installApk(File('unused.apk')),
          throwsA(isA<UpdaterException>()),
        );
        complete.complete(ResponseBody.fromBytes(utf8.encode('abc'), 200));
        expect(await (await download).readAsString(), 'abc');
      },
    );
  });

  test('Windows handshake binds the nonce and this instance PID', () {
    const nonce =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    expect(
      windowsInstallerArguments(
        File('/tmp/update.exe'),
        nonce: nonce,
        processId: 1234,
      ),
      [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/UPDATE=1',
        '/UPDATEPID=1234',
        '/UPDATENONCE=$nonce',
        '/UPDATEREADY=/tmp/update.exe.$nonce.ready',
      ],
    );
  });
}
