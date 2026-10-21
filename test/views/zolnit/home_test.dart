import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/home.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

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

void main() {
  late ZolnitSessionController session;
  late ProviderContainer container;
  late List<http.Request> requests;
  bool loginFails = false;
  bool cancelled = false;

  setUpAll(() async {
    final font = Platform.environment['ZOLNIT_FONT_PATH'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    final cjk = Platform.environment['ZOLNIT_CJK_FONT_PATH'];
    if (cjk != null) {
      final loader = FontLoader('ZolNitCJK')
        ..addFont(File(cjk).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  setUp(() {
    requests = [];
    loginFails = false;
    cancelled = false;
    final api = XboardClient(
      origin: Uri.parse('https://panel.example'),
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/login')) {
          return http.Response(
            loginFails
                ? '{"message":"PRIVATE_DO_NOT_RENDER"}'
                : '{"data":{"auth_data":"Bearer fixture"}}',
            loginFails ? 401 : 200,
          );
        }
        dynamic data;
        if (path.endsWith('/user/info')) {
          data = {'email': 'client@example.com'};
        } else if (path.endsWith('/getSubscribe')) {
          data = {
            'plan_id': null,
            'u': 0,
            'd': 0,
            'transfer_enable': 0,
            'subscribe_url': 'https://panel.example/s/PRIVATE_DO_NOT_RENDER',
            'token': 'PRIVATE_DO_NOT_RENDER',
            'uuid': 'UUID_DO_NOT_RENDER',
          };
        } else if (path.endsWith('/server/fetch')) {
          data = <Json>[];
        } else if (path.endsWith('/plan/fetch')) {
          data = [
            {'id': 1, 'name': 'Test Plan', 'month_price': 1200},
          ];
        } else if (path.endsWith('/order/fetch')) {
          data = [
            {'trade_no': 'orderA', 'status': 0, 'total_amount': 1200},
          ];
        } else if (path.endsWith('/order/save')) {
          data = 'orderA';
        } else if (path.endsWith('/getPaymentMethod')) {
          data = [
            {'id': 1, 'name': 'Stripe'},
          ];
        } else if (path.endsWith('/subscriptions/1/cancel')) {
          cancelled = true;
          data = {'cancel_at_period_end': true};
        } else if (path.endsWith('/subscriptions')) {
          data = {
            'subscriptions': [
              {
                'id': 1,
                'plan_name': 'Existing Plan',
                'paid_through': 1795000000,
                'next_renewal_at': cancelled ? null : 1795000000,
                'can_cancel': !cancelled,
                'can_resume': cancelled,
              },
            ],
            'entitlement': {
              'source': 'paid',
              'label': 'Paid access',
              'expires_at': 1795000000,
            },
          };
        } else {
          return http.Response('{}', 404);
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
  });

  tearDown(() {
    container.dispose();
    session.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool phone = false,
    bool dark = false,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = phone
        ? const Size(390, 844)
        : const Size(1200, 850);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          locale: locale,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            fontFamilyFallback: const ['ZolNitCJK'],
          ).withAppShapes.withAppTypography.withAppSurfaces,
          child: const RepaintBoundary(
            key: ValueKey('zolnit-capture'),
            child: ZolnitHomePage(),
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

  testWidgets('signed-out brand screen is offline and validates input', (
    tester,
  ) async {
    await mount(tester);
    expect(requests, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    expect(requests, isEmpty);
    expect(find.textContaining('valid email'), findsWidgets);
    await capture(tester, 'login-desktop-light');
  });

  testWidgets(
    'login flow renders empty nodes and legacy plan prices without secrets',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('zolnit-email')),
        'client@example.com',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('zolnit-password')),
          matching: find.byType(TextFormField),
        ),
        'password123',
      );
      await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
      await tester.pumpAndSettle();
      expect(session.authenticated, isTrue);
      expect(
        find.text('No nodes are available for this subscription.'),
        findsOneWidget,
      );
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await capture(tester, 'dashboard-desktop-light');
      await tester.tap(find.text('Plans').first);
      await tester.pumpAndSettle();
      expect(find.text('Test Plan'), findsOneWidget);
      expect(find.textContaining('12.00'), findsOneWidget);
      await capture(tester, 'plans-desktop-light');
      await tester.tap(find.text('Account').first);
      await tester.pumpAndSettle();
      expect(find.text('client@example.com'), findsOneWidget);
      expect(find.text('Existing Plan'), findsOneWidget);
      expect(find.textContaining('UUID_DO_NOT_RENDER'), findsNothing);
      await capture(tester, 'account-desktop-light');
    },
  );

  testWidgets(
    'ordinary order uses native compatibility period and original ID',
    (tester) async {
      await session.login('client@example.com', 'password123');
      await mount(tester);
      await tester.tap(find.text('Plans').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create order'));
      await tester.pumpAndSettle();
      expect(
        requests.where((request) => request.url.path.endsWith('/order/save')),
        isEmpty,
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final request = requests.singleWhere(
        (request) => request.url.path.endsWith('/order/save'),
      );
      expect(jsonDecode(request.body), {'plan_id': 1, 'period': 'month_price'});
      expect(find.text('orderA'), findsOneWidget);
      expect(find.text('Awaiting payment'), findsOneWidget);
    },
  );

  testWidgets(
    'renewal cancellation waits for confirmation and renders server result',
    (tester) async {
      await session.login('client@example.com', 'password123');
      await session.refreshBilling();
      await mount(tester);
      await tester.tap(find.text('Account').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel automatic renewal'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.url.path.endsWith('/cancel')), isEmpty);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(
        requests.where((r) => r.url.path.endsWith('/subscriptions/1/cancel')),
        hasLength(1),
      );
      expect(find.text('Resume automatic renewal'), findsOneWidget);
    },
  );

  testWidgets(
    'phone dark layout has native dock and redacts failed login response',
    (tester) async {
      loginFails = true;
      await mount(tester, phone: true, dark: true);
      await tester.enterText(
        find.byKey(const ValueKey('zolnit-email')),
        'client@example.com',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('zolnit-password')),
          matching: find.byType(TextFormField),
        ),
        'password123',
      );
      await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
      await tester.pumpAndSettle();
      expect(session.authenticated, isFalse);
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      expect(find.textContaining('Could not complete'), findsOneWidget);
      loginFails = false;
      await session.login('client@example.com', 'password123');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDock), findsOneWidget);
      await capture(tester, 'dashboard-phone-dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chinese business labels render in the branded host', (
    tester,
  ) async {
    await mount(tester, locale: const Locale('zh', 'CN'));
    expect(find.text('欢迎回来'), findsOneWidget);
    await capture(tester, 'login-desktop-zh-light');
    await session.login('client@example.com', 'password123');
    await tester.pumpAndSettle();
    expect(find.text('当前订阅暂无可用节点。'), findsOneWidget);
    await capture(tester, 'dashboard-desktop-zh-light');
  });
}
