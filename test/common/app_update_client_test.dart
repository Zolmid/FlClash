import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_installer.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_client.dart';
import 'package:fl_clash/common/constant.dart' show browserUa;
import 'package:fl_clash/common/request.dart';
import 'package:test/test.dart';

const _hash =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _name = 'ZolNit-0.9.4-android-arm64-v8a.apk';
const _url = 'https://link.zolmid.com/client/downloads/v0.9.4/$_name';
const _metadataUrl = 'https://link.zolmid.com/client/releases.json';
const _disabledMetadata = {
  'schema_version': 1,
  'app_id': 'com.zolmid.zolnit',
  'updates_enabled': false,
  'releases': <Object>[],
};
final _enabledMetadata = {
  ..._disabledMetadata,
  'updates_enabled': true,
  'releases': [
    {
      'tag': 'v0.9.4',
      'notes': '- fixed',
      'assets': [
        {'name': _name, 'url': _url, 'size': 3, 'sha256': _hash},
      ],
    },
  ],
};

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
  FutureOr<ResponseBody> Function(RequestOptions) respond, {
  Map<String, dynamic>? headers,
}) {
  final client = AppUpdateClient(
    dio: Dio(BaseOptions(headers: headers))
      ..httpClientAdapter = _Adapter(respond),
  );
  addTearDown(client.close);
  return client;
}

void main() {
  test(
    'website JSON rejects duplicate keys, oversized input and nonstable tags',
    () {
      final body = jsonEncode(_enabledMetadata);
      for (final duplicate in [
        '"schema_version":1,"schema_version":1',
        r'"schema_version":1,"\u0073chema_version":1',
      ]) {
        expect(
          () => decodeWebsiteReleases(
            body.replaceFirst('"schema_version":1', duplicate),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => decodeWebsiteReleases(' ' * (maxWebsiteManifestBytes + 1)),
        throwsFormatException,
      );
      for (final version in [
        'v0.9.4-pre.1',
        'v0.9.4+1',
        'v2147483648.0.0',
        'v01.2.3',
      ]) {
        expect(
          () => decodeWebsiteReleases(body.replaceAll('v0.9.4', version)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'selects the latest release containing this exact platform package',
    () async {
      final older = (_enabledMetadata['releases'] as List).single as Map;
      final client = _client(
        (_) => _json({
          ..._enabledMetadata,
          'releases': [
            older,
            {
              'tag': 'v0.9.5',
              'notes': '',
              'assets': [
                {
                  'name': 'ZolNit-0.9.5-macos-arm64.dmg',
                  'url':
                      'https://link.zolmid.com/client/downloads/v0.9.5/ZolNit-0.9.5-macos-arm64.dmg',
                  'size': 3,
                  'sha256': _hash,
                },
              ],
            },
          ],
        }),
      );
      addTearDown(client.close);
      expect(
        (await client.latestRelease(
          target: const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
        ))?.tag,
        'v0.9.4',
      );
      expect(
        (await client.latestRelease(
          target: const UpdateTarget(UpdatePackage.macosDmg, 'arm64'),
        ))?.tag,
        'v0.9.5',
      );
      expect(
        await client.latestRelease(
          target: const UpdateTarget(UpdatePackage.windowsInstaller, 'x64'),
        ),
        isNull,
      );
    },
  );
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

  group('website release metadata', () {
    test('selects a complete enabled release and rejects downgrades', () async {
      final client = _client((_) => _json(_enabledMetadata));
      final release = await client.checkForUpdate(currentVersion: '0.9.3');
      expect(release?.tag, 'v0.9.4');
      expect(release?.notes, '- fixed');
      expect(
        planAppUpdate(
          release!,
          const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
        )?.asset.url,
        _url,
      );
      expect(await client.checkForUpdate(currentVersion: '0.9.4'), isNull);
      expect(await client.checkForUpdate(currentVersion: '0.9.5'), isNull);
    });

    test('chooses the newest version regardless of array order', () async {
      final newer = {
        'tag': 'v0.9.5',
        'notes': '',
        'assets': [
          {
            'name': 'ZolNit-0.9.5-android-arm64-v8a.apk',
            'url':
                'https://link.zolmid.com/client/downloads/v0.9.5/ZolNit-0.9.5-android-arm64-v8a.apk',
            'size': 3,
            'sha256': _hash,
          },
        ],
      };
      final client = _client(
        (_) => _json({
          ..._enabledMetadata,
          'releases': [newer, ..._enabledMetadata['releases'] as List],
        }),
      );
      expect((await client.latestRelease())?.tag, 'v0.9.5');
    });

    test('empty enabled list stays disabled', () async {
      final client = _client(
        (_) => _json({..._enabledMetadata, 'releases': []}),
      );
      expect(await client.latestRelease(), isNull);
    });

    test('rejects unsafe and ambiguous enabled manifests', () async {
      final base = (_enabledMetadata['releases'] as List).single as Map;
      final asset = (base['assets'] as List).single as Map;
      for (final invalid in <Object>[
        {...base, 'tag': 'v0.9.3'},
        {
          ...base,
          'assets': [asset, asset],
        },
        {
          ...base,
          'assets': [
            {...asset, 'size': 0},
          ],
        },
        {
          ...base,
          'assets': [
            {...asset, 'sha256': 'bad'},
          ],
        },
        {
          ...base,
          'assets': [
            {...asset, 'name': 'FlClash-0.9.4-android-arm64-v8a.apk'},
          ],
        },
        {
          ...base,
          'assets': [
            {...asset, 'url': 'https://github.com/x/y'},
          ],
        },
        {
          ...base,
          'assets': [
            {...asset, 'url': 'https://cdn.zolmid.com/$_name'},
          ],
        },
        {
          ...base,
          'assets': [
            {
              ...asset,
              'url': 'http://link.zolmid.com/client/downloads/v0.9.4/$_name',
            },
          ],
        },
        {
          ...base,
          'assets': [
            {...asset, 'url': '$_url?download=1'},
          ],
        },
        {
          ...base,
          'assets': [
            {
              ...asset,
              'url':
                  'https://link.zolmid.com/client/downloads/v0.9.4/../$_name',
            },
          ],
        },
        {...base, 'channel': 'stable'},
        {
          ...base,
          'assets': [
            {...asset, 'platform': 'android'},
          ],
        },
      ]) {
        final client = _client(
          (_) => _json({
            ..._enabledMetadata,
            'releases': [invalid],
          }),
        );
        expect(await client.latestRelease(), isNull, reason: '$invalid');
      }
      final duplicate = _client(
        (_) => _json({
          ..._enabledMetadata,
          'releases': [base, base],
        }),
      );
      expect(await duplicate.latestRelease(), isNull);
      final semanticDuplicate = _client(
        (_) => _json({
          ..._enabledMetadata,
          'releases': [
            base,
            {
              ...base,
              'tag': 'v0.9.4+abc',
              'assets': [
                {
                  ...asset,
                  'name': 'ZolNit-0.9.4+abc-android-arm64-v8a.apk',
                  'url':
                      'https://link.zolmid.com/client/downloads/v0.9.4+abc/ZolNit-0.9.4+abc-android-arm64-v8a.apk',
                },
              ],
            },
          ],
        }),
      );
      expect(await semanticDuplicate.latestRelease(), isNull);
    });

    test('uses one fixed GET without credentials or redirects', () async {
      final requests = <RequestOptions>[];
      final client = _client((options) {
        requests.add(options);
        return _json(_disabledMetadata);
      }, headers: {'User-Agent': browserUa});

      expect(await client.checkForUpdate(currentVersion: '0.9.0'), isNull);
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.uri.toString(), _metadataUrl);
      expect(request.followRedirects, isFalse);
      expect(request.validateStatus(HttpStatus.movedTemporarily), isFalse);
      expect(
        request.headers.entries
            .singleWhere(
              (entry) => entry.key.toLowerCase() == HttpHeaders.userAgentHeader,
            )
            .value,
        'ZolNit/0.9.0',
      );
      final headerNames = request.headers.keys.map((key) => key.toLowerCase());
      expect(headerNames, isNot(contains(HttpHeaders.authorizationHeader)));
      expect(headerNames, isNot(contains(HttpHeaders.cookieHeader)));
    });

    test('the legacy release lookup uses the same client', () async {
      final requests = <RequestOptions>[];
      final client = _client((options) {
        requests.add(options);
        return _json(_disabledMetadata);
      });
      final legacy = Request(updateClient: client);

      expect(await legacy.latestRelease(), isNull);
      expect(requests.single.uri.toString(), _metadataUrl);
      expect(
        requests.single.headers.entries
            .singleWhere(
              (entry) => entry.key.toLowerCase() == HttpHeaders.userAgentHeader,
            )
            .value,
        'ZolNit/0',
      );
    });

    test(
      'rejects malformed, wrong identity, schema and enabled entries',
      () async {
        final invalid = <ResponseBody>[
          ResponseBody.fromString('not json', 200),
          _json({'schema_version': 1}),
          _json({..._disabledMetadata, 'app_id': 'com.follow.clash'}),
          _json({..._disabledMetadata, 'schema_version': 2}),
          _json({
            ..._disabledMetadata,
            'releases': ['unexpected'],
          }),
          _json({..._disabledMetadata, 'updates_enabled': true}),
          _json({
            ..._disabledMetadata,
            'updates_enabled': true,
            'releases': [
              {'tag': 'v99.0.0', 'assets': []},
            ],
          }),
        ];
        for (final body in invalid) {
          final requests = <Uri>[];
          final client = _client((options) {
            requests.add(options.uri);
            return body;
          });
          expect(await client.checkForUpdate(currentVersion: '0.9.0'), isNull);
          expect(requests, [Uri.parse(_metadataUrl)]);
        }
      },
    );

    test('HTTP errors and redirects have no GitHub fallback', () async {
      for (final status in [302, 403, 404, 503]) {
        final requests = <Uri>[];
        final client = _client((options) {
          requests.add(options.uri);
          return ResponseBody.fromString(
            '',
            status,
            headers: {
              if (status == 302)
                HttpHeaders.locationHeader: [
                  'https://link.zolmid.com/client/releases.json',
                ],
            },
          );
        });
        expect(await client.latestRelease(), isNull);
        expect(requests, [Uri.parse(_metadataUrl)]);
      }
    });

    test('network errors have no fallback', () async {
      final requests = <Uri>[];
      final client = _client((options) {
        requests.add(options.uri);
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      expect(await client.latestRelease(), isNull);
      expect(requests, [Uri.parse(_metadataUrl)]);
    });

    test('package redirects are refused without a second request', () async {
      final directory = await Directory.systemTemp.createTemp(
        'zolnit-redirect-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final requests = <RequestOptions>[];
      final client = _client((options) {
        requests.add(options);
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            HttpHeaders.locationHeader: ['https://github.com/other/package'],
          },
        );
      });
      final file = '${directory.path}/package';
      await expectLater(
        client.downloadFile(_url, file, retries: 0),
        throwsA(isA<DioException>()),
      );
      expect(requests, hasLength(1));
      expect(requests.single.followRedirects, isFalse);
      expect(File(file).existsSync(), isFalse);
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

    test('refuses a mismatched package name before downloading', () async {
      var requests = 0;
      final client = _client((_) {
        requests++;
        return ResponseBody.fromBytes([], 200);
      });
      final installer = AppInstaller(
        client: client,
        tempDirectory: () async => directory,
      );
      await expectLater(
        installer.download(
          const AppUpdatePlan(
            target: UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
            asset: ReleaseAsset(
              name: 'ZolNit-0.9.4-extra-android-arm64-v8a.apk',
              url:
                  'https://link.zolmid.com/client/downloads/v0.9.4/ZolNit-0.9.4-extra-android-arm64-v8a.apk',
              size: 3,
              sha256: _hash,
            ),
          ),
        ),
        throwsA(isA<UpdaterException>()),
      );
      expect(requests, 0);
    });

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
