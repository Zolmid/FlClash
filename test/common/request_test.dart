import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update_client.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/request.dart';
import 'package:flutter_test/flutter_test.dart';

class _StalledHttpClient extends Fake implements HttpClient {
  @override
  Duration? connectionTimeout;

  @override
  String Function(Uri url)? findProxy;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      Completer<HttpClientRequest>().future;
}

class _HostAdapter implements HttpClientAdapter {
  _HostAdapter(this.byHost);

  final Map<String, ResponseBody Function()> byHost;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return byHost[options.uri.host]!();
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'URL profile labels use a decoded filename and ignore unsafe segments',
    () {
      expect(
        getFileNameFromUrl(
          'https://example.com/profiles/My%20Proxy.yaml?token=secret',
        ),
        'My Proxy.yaml',
      );
      for (final url in [
        null,
        '',
        'https://example.com/subscribe?file=proxy.yaml',
        'https://example.com/',
        'https://example.com/.yaml',
        'https://example.com/proxy.',
        'https://example.com/sub%2Fproxy.yaml',
        'https://example.com/sub%5Cproxy.yaml',
        'https://example.com/line%0Abreak.yaml',
      ]) {
        expect(getFileNameFromUrl(url), isNull, reason: '$url');
      }
    },
  );

  test('getTextResponseForUrl propagates the typed DioException', () async {
    // flutter_test's mocked HttpClient answers every request with HTTP 400,
    // which Dio surfaces as a badResponse DioException.
    await expectLater(
      request.getTextResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  test('getFileResponseForUrl propagates the typed DioException', () async {
    await expectLater(
      request.getFileResponseForUrl('http://127.0.0.1/anything'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.badResponse,
        ),
      ),
    );
  });

  group('website update lookup', () {
    const metadataUrl = 'https://link.zolmid.com/client/releases.json';
    const disabled = {
      'schema_version': 1,
      'app_id': 'com.zolmid.zolnit',
      'updates_enabled': false,
      'releases': <Object>[],
    };

    (Request, _HostAdapter, _HostAdapter) requestAnswering(
      ResponseBody Function() answer,
    ) {
      final website = _HostAdapter({'link.zolmid.com': answer});
      final legacy = _HostAdapter({});
      final client = AppUpdateClient(dio: Dio()..httpClientAdapter = website);
      addTearDown(client.close);
      final request = Request(updateClient: client)
        ..dio.httpClientAdapter = legacy;
      return (request, website, legacy);
    }

    void expectWebsiteOnly(_HostAdapter website, _HostAdapter legacy) {
      expect(website.requests, hasLength(1));
      final sent = website.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.toString(), metadataUrl);
      expect(sent.followRedirects, isFalse);
      expect(sent.validateStatus(HttpStatus.movedTemporarily), isFalse);
      expect(
        sent.headers.entries
            .singleWhere(
              (entry) => entry.key.toLowerCase() == HttpHeaders.userAgentHeader,
            )
            .value,
        'ZolNit/0',
      );
      expect(
        sent.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains(HttpHeaders.authorizationHeader)),
      );
      expect(
        sent.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains(HttpHeaders.cookieHeader)),
      );
      expect(legacy.requests, isEmpty);
    }

    test('disabled empty website metadata offers no release', () async {
      final (request, website, legacy) = requestAnswering(
        () => ResponseBody.fromString(jsonEncode(disabled), 200),
      );
      expect(await request.latestRelease(), isNull);
      expectWebsiteOnly(website, legacy);
    });

    test('missing and wrong schema offer no release', () async {
      for (final metadata in [
        {'schema_version': 1},
        {...disabled, 'schema_version': 2},
        {...disabled, 'app_id': 'com.follow.clash'},
      ]) {
        final (request, website, legacy) = requestAnswering(
          () => ResponseBody.fromString(jsonEncode(metadata), 200),
        );
        expect(await request.latestRelease(), isNull);
        expectWebsiteOnly(website, legacy);
      }
    });

    test('enabled entries and HTTP errors have no GitHub fallback', () async {
      for (final answer in <ResponseBody Function()>[
        () => ResponseBody.fromString(
          jsonEncode({
            ...disabled,
            'updates_enabled': true,
            'releases': [
              {'tag': 'v99.0.0'},
            ],
          }),
          200,
        ),
        () => ResponseBody.fromString('', 404),
        () => ResponseBody.fromString(
          '',
          302,
          headers: {
            HttpHeaders.locationHeader: [
              'https://github.com/Zolmid/FlClash/releases/latest',
            ],
          },
        ),
      ]) {
        final (request, website, legacy) = requestAnswering(answer);
        expect(await request.latestRelease(), isNull);
        expectWebsiteOnly(website, legacy);
      }
    });
  });

  group('downloadTarget', () {
    test('sends a URL without credentials unchanged', () {
      final target = downloadTarget('https://example.com/a.yaml?x=1');

      expect(target.uri.toString(), 'https://example.com/a.yaml?x=1');
      expect(target.headers, isEmpty);
    });

    test('moves decoded credentials into the Authorization header', () {
      for (final url in [
        'https://me@mail.com:p:w@dav.example.com/dav/a.yaml',
        'https://me%40mail.com:p%3Aw@dav.example.com/dav/a.yaml',
      ]) {
        final target = downloadTarget(url);

        expect(target.uri.toString(), 'https://dav.example.com/dav/a.yaml');
        expect(
          target.headers[HttpHeaders.authorizationHeader],
          'Basic ${base64.encode(utf8.encode('me@mail.com:p:w'))}',
        );
      }
    });
  });

  group('decompressUnlabeled', () {
    final yaml = utf8.encode('proxies: []\n');

    test('inflates a gzip or zlib body that arrived unlabeled', () {
      for (final codec in [gzip, zlib]) {
        final body = Uint8List.fromList(codec.encode(yaml));

        expect(decompressUnlabeled(body), yaml);
      }
    });

    test('leaves a plain body untouched', () {
      final body = Uint8List.fromList(yaml);

      expect(decompressUnlabeled(body), same(body));
    });

    test('keeps a body that only starts like gzip', () {
      final body = Uint8List.fromList([0x1f, 0x8b, 1, 2, 3]);

      expect(decompressUnlabeled(body), same(body));
    });
  });

  testWidgets('a stalled download fails at the shared download deadline', (
    tester,
  ) async {
    late final Future<Response<String>> pending;
    HttpOverrides.runZoned(() {
      pending = Request().getTextResponseForUrl('http://127.0.0.1/stalled');
    }, createHttpClient: (_) => _StalledHttpClient());
    var settled = false;
    final outcome = expectLater(
      pending.whenComplete(() => settled = true),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );

    await tester.pump(downloadTimeoutDuration - const Duration(seconds: 1));
    expect(settled, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await outcome;
  });
}
