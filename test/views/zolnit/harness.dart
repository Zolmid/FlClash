import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/home.dart';
import 'package:fl_clash/views/zolnit/skin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../helpers/app_paths.dart';
import '../../helpers/test_app.dart';

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
      HostedCheckout(Uri.parse('https://checkout.stripe.com/pay'));

  @override
  Future<int> status(String tradeNo) async => 0;
}

const _gib = 1073741824;

int _seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;

/// A panel that answers like the real one with the preview's sample account.
http.Response zolnitPanelFixture(http.Request request) {
  final path = request.url.path;
  if (path.endsWith('/login')) {
    return http.Response('{"data":{"auth_data":"Bearer fixture"}}', 200);
  }
  final now = DateTime.now();
  dynamic data;
  if (path.endsWith('/user/info')) {
    data = {'email': 'lin@example.com'};
  } else if (path.endsWith('/getSubscribe')) {
    data = {
      'plan_id': 1,
      'plan': {'id': 1, 'name': '轻享', 'device_limit': 2},
      'u': 20 * _gib,
      'd': (65.6 * _gib).round(),
      'transfer_enable': 150 * _gib,
      'expired_at': _seconds(now.add(const Duration(days: 31))),
      'reset_day': 12,
      'alive_ip': 1,
      'email': 'lin@example.com',
      'subscribe_url': 'https://panel.example/s/PRIVATE_DO_NOT_RENDER',
      'token': 'PRIVATE_DO_NOT_RENDER',
    };
  } else if (path.endsWith('/server/fetch')) {
    data = [
      {
        'id': 101,
        'name': '\u{1F1ED}\u{1F1F0} 香港 · 轻风 01',
        'tags': ['优选线路'],
        'rate': '1',
      },
      {
        'id': 102,
        'name': '\u{1F1EF}\u{1F1F5} 日本 · 东京 01',
        'tags': ['优选线路'],
        'rate': '1',
      },
      {
        'id': 103,
        'name': '\u{1F1F8}\u{1F1EC} 新加坡 · 狮城 01',
        'tags': ['低延迟'],
        'rate': '1.5',
      },
    ];
  } else if (path.endsWith('/plan/fetch')) {
    data = [
      {
        'id': 1,
        'name': '轻享',
        'content': '覆盖五个常用地区\n适合浏览、办公与轻量影音',
        'transfer_enable': 150,
        'device_limit': 2,
        'month_price': 2800,
        'quarter_price': 7980,
        'year_price': 26880,
      },
      {
        'id': 2,
        'name': '畅享',
        'content': '包含优选高速节点\n适合多设备办公与高清影音',
        'transfer_enable': 400,
        'device_limit': 5,
        'month_price': 4800,
        'quarter_price': 13680,
        'year_price': 46080,
      },
      {
        'id': 3,
        'name': '尊享',
        'content': '包含全部优选节点\n适合高频使用与大流量需求',
        'transfer_enable': 1000,
        'device_limit': 8,
        'month_price': 8800,
        'quarter_price': 25080,
        'year_price': 84480,
      },
    ];
  } else if (path.endsWith('/notice/fetch')) {
    data = [
      {
        'id': 1,
        'title': '一份更轻盈的连接体验',
        'content': '<p>全新的 ZolNit 客户端上线。</p>',
        'tags': ['产品动态'],
        'created_at': _seconds(DateTime.utc(2026, 10, 20, 8)),
      },
      {
        'id': 2,
        'title': '香港与日本优选节点已更新',
        'content': '<p>请同步连接配置。</p>',
        'tags': ['线路动态'],
        'created_at': _seconds(DateTime.utc(2026, 10, 19, 8)),
      },
      {
        'id': 3,
        'title': '续费之前，先看看套餐余量',
        'content': '<p>在套餐页查看到期时间。</p>',
        'tags': ['使用提示'],
        'created_at': _seconds(DateTime.utc(2026, 10, 17, 8)),
      },
    ];
  } else if (path.endsWith('/order/save')) {
    data = 'trade-1';
  } else if (path.endsWith('/order/fetch')) {
    data = <Json>[];
  } else if (path.endsWith('/getPaymentMethod')) {
    data = [
      {'id': 1, 'name': 'Stripe'},
    ];
  } else if (path.endsWith('/zolnit-stripe/plans')) {
    data = {'plans': <Json>[]};
  } else if (path.endsWith('/zolnit-stripe/config')) {
    data = {'enabled': false, 'configured': false};
  } else if (path.endsWith('/subscriptions')) {
    data = {'subscriptions': <Json>[]};
  } else {
    return http.Response('{}', 404);
  }
  return zolnitJson(data);
}

http.Response zolnitJson(dynamic data) => http.Response.bytes(
  utf8.encode(jsonEncode({'data': data})),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// The same panel for an account without a plan, nodes, plans or notices.
http.Response zolnitEmptyPanelFixture(http.Request request) {
  final path = request.url.path;
  if (path.endsWith('/getSubscribe')) {
    return zolnitJson({
      'plan_id': null,
      'u': 0,
      'd': 0,
      'transfer_enable': 0,
      'subscribe_url': 'https://panel.example/s/PRIVATE_DO_NOT_RENDER',
    });
  }
  if (path.endsWith('/server/fetch') ||
      path.endsWith('/plan/fetch') ||
      path.endsWith('/notice/fetch')) {
    return zolnitJson(<Json>[]);
  }
  return zolnitPanelFixture(request);
}

const zolnitViewports = <ZolnitSkin, (Size, TargetPlatform)>{
  ZolnitSkin.macos: (Size(1440, 900), TargetPlatform.macOS),
  ZolnitSkin.windows: (Size(1280, 800), TargetPlatform.windows),
  ZolnitSkin.linux: (Size(1280, 800), TargetPlatform.linux),
  ZolnitSkin.ios: (Size(390, 844), TargetPlatform.iOS),
  ZolnitSkin.android: (Size(412, 915), TargetPlatform.android),
};

/// Mounts the signed-in ZolNit host on a platform viewport and captures it.
///
/// Set ZOLNIT_CAPTURE_DIR to write PNGs; ZOLNIT_FONT_PATH,
/// ZOLNIT_CJK_FONT_PATH and ZOLNIT_CJK_BOLD_FONT_PATH name the fonts to load.
class ZolnitHarness {
  ZolnitHarness._();

  late ZolnitSessionController session;
  late ProviderContainer container;
  late Directory _paths;
  http.Response Function(http.Request) panel = zolnitPanelFixture;
  final requests = <http.Request>[];

  static ZolnitHarness register() {
    final harness = ZolnitHarness._();
    setUpAll(harness._loadFonts);
    setUp(harness._start);
    tearDown(harness._stop);
    return harness;
  }

  Future<void> _loadFonts() async {
    Future<void> load(String family, List<String?> paths) async {
      final loader = FontLoader(family);
      for (final path in paths.whereType<String>()) {
        loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }

    final env = Platform.environment;
    await load('ZolNitLatin', [env['ZOLNIT_FONT_PATH']]);
    await load('ZolNitCJK', [
      env['ZOLNIT_CJK_FONT_PATH'],
      env['ZOLNIT_CJK_BOLD_FONT_PATH'],
    ]);
    await load('Twemoji', ['assets/fonts/Twemoji.Mozilla.ttf']);
  }

  Future<void> _start() async {
    _paths = await Directory.systemTemp.createTemp('zolnit-screens-');
    await useAppPaths(_paths);
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        return panel(request);
      }),
    );
    session = ZolnitSessionController(
      api: api,
      billing: ZolnitBillingClient(api),
      checkout: CheckoutController(
        backend: _Backend(),
        platform: _Platform(),
        allowedHttpsOrigins: {'https://checkout.stripe.com'},
        allowStripe: true,
      ),
    );
    container = ProviderContainer(
      overrides: [
        zolnitSessionProvider.overrideWithValue(session),
        zolnitSyncProfileProvider.overrideWithValue(() async => null),
        safeModeProvider.overrideWithValue(true),
      ],
    );
    globalState.container = container;
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    panel = zolnitPanelFixture;
    requests.clear();
    await relogin();
  }

  Future<void> relogin() async {
    session.logout();
    await session.login('lin@example.com', 'password123');
    expect(session.authenticated, isTrue, reason: session.failure);
  }

  Future<void> _stop() async {
    container.dispose();
    session.dispose();
    await _paths.delete(recursive: true);
  }

  Future<void> mount(
    WidgetTester tester,
    ZolnitSkin skin, {
    bool dark = false,
    Locale locale = const Locale('zh', 'CN'),
    Size? size,
  }) async {
    final (viewport, platform) = zolnitViewports[skin]!;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size ?? viewport;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          locale: locale,
          theme: ThemeData(
            platform: platform,
            brightness: dark ? Brightness.dark : Brightness.light,
            fontFamily: 'ZolNitLatin',
            fontFamilyFallback: const ['ZolNitCJK'],
          ).withAppShapes.withAppTypography.withAppSurfaces,
          child: RepaintBoundary(
            key: const ValueKey('zolnit-capture'),
            child: ZolnitHomePage(skin: skin),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['ZOLNIT_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('zolnit-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File('$directory/$name.png');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}
