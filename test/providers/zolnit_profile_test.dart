import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      'proxies: []\nproxy-groups: []\nrules: [MATCH,DIRECT]\n',
      200,
      headers: {
        'content-type': ['text/yaml'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Platform implements CheckoutPlatform {
  @override
  Future<bool> open(Uri uri) async => true;

  @override
  Future<void> confirmStripe(
    StripeCheckout action, {
    required bool Function() isCurrent,
  }) async {}
}

class _Backend implements CheckoutBackend {
  @override
  Future<CheckoutAction> start(String tradeNo, int methodId) async =>
      const StatusOnlyCheckout();

  @override
  Future<int> status(String tradeNo) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProviderContainer container;
  late ZolnitSessionController session;
  late _Core core;
  late _Adapter adapter;
  late Profile existing;
  late File target;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zolnit-profile-test-');
    await useAppPaths(directory);
    await mockPreferences();
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        final path = request.url.path;
        dynamic data;
        if (path.endsWith('/login')) {
          data = {'auth_data': 'Bearer fixture'};
        } else if (path.endsWith('/info')) {
          data = {'email': 'client@example.com'};
        } else if (path.endsWith('/getSubscribe')) {
          data = {
            'email': 'client@example.com',
            'plan_id': 1,
            'subscribe_url':
                'https://sub.example/s/fixture?existing=preserved&flag=clash',
          };
        } else if (path.endsWith('/server/fetch')) {
          data = [
            {'id': 1, 'name': 'Panel node'},
          ];
        } else {
          data = <Json>[];
        }
        return http.Response(jsonEncode({'data': data}), 200);
      }),
    );
    session = ZolnitSessionController(
      api: api,
      billing: ZolnitBillingClient(api),
      checkout: CheckoutController(
        backend: _Backend(),
        platform: _Platform(),
        allowedHttpsOrigins: const {},
        allowStripe: true,
      ),
    );
    await session.login('client@example.com', 'password123');
    existing = Profile.normal(
      label: zolnitProfileLabel(session),
      url: 'https://sub.example/s/old',
    ).copyWith(id: 123);
    target = File(await appPath.getProfilePath('123'));
    await target.parent.create(recursive: true);
    await target.writeAsString('original');
    core = _Core();
    when(() => core.validateConfig(any())).thenAnswer((_) async => '');
    adapter = _Adapter();
    final dio = Dio(
      BaseOptions(responseType: ResponseType.bytes, followRedirects: false),
    )..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(session),
        zolnitProfileDownloaderProvider.overrideWithValue(dio),
        profilesProvider.overrideWith(() => TestProfiles([existing])),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    container.listen(profilesProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    globalState.container = container;
  });

  tearDown(() async {
    container.dispose();
    session.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'sync is single flight, keeps profile ID and never forwards API Bearer',
    () async {
      final sync = container.read(zolnitSyncProfileProvider);
      final ids = await Future.wait([sync(), sync()]);
      expect(ids, [123, 123]);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.queryParameters, {
        'existing': 'preserved',
        'flag': 'meta',
      });
      expect(
        adapter.requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(container.read(profilesProvider).single.id, 123);
      expect(await target.readAsString(), contains('proxy-groups'));
      await sync();
      expect(container.read(profilesProvider), hasLength(1));
    },
  );

  test(
    'failed validation preserves existing profile and redacts the cause',
    () async {
      when(
        () => core.validateConfig(any()),
      ).thenThrow(StateError('PRIVATE_DO_NOT_RENDER'));
      await expectLater(
        container.read(zolnitSyncProfileProvider)(),
        throwsA(
          isA<ClientFailure>().having(
            (error) => error.toString(),
            'message',
            'ClientFailure(profile_sync_failed)',
          ),
        ),
      );
      expect(await target.readAsString(), 'original');
      expect(container.read(profilesProvider).single.url, existing.url);
    },
  );

  test('logout during validation cannot publish a late profile', () async {
    final started = Completer<void>();
    final validation = Completer<String>();
    when(() => core.validateConfig(any())).thenAnswer((_) {
      started.complete();
      return validation.future;
    });
    final result = container.read(zolnitSyncProfileProvider)();
    final assertion = expectLater(
      result,
      throwsA(
        isA<ClientFailure>().having(
          (error) => error.code,
          'code',
          'superseded',
        ),
      ),
    );
    await started.future;
    await session.logout();
    validation.complete('');
    await assertion;
    expect(await target.readAsString(), 'original');
    expect(container.read(profilesProvider).single.url, existing.url);
    expect(
      directory
          .listSync(recursive: true)
          .where((file) => file.path.endsWith('.partial')),
      isEmpty,
    );
  });

  test(
    'logout before scheduled sync prevents any subscription download',
    () async {
      final result = container.read(zolnitSyncProfileProvider)();
      final assertion = expectLater(
        result,
        throwsA(
          isA<ClientFailure>().having(
            (error) => error.code,
            'code',
            'superseded',
          ),
        ),
      );
      await session.logout();
      await assertion;
      expect(adapter.requests, isEmpty);
      expect(await target.readAsString(), 'original');
    },
  );
}
