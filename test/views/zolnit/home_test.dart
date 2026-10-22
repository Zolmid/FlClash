import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/zolnit.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/zolnit/brand.dart';
import 'package:fl_clash/views/zolnit/connect_art.dart';
import 'package:fl_clash/views/zolnit/home.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../helpers/app_paths.dart';
import '../../helpers/test_app.dart';

class _Platform implements CheckoutPlatform {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

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

enum _MockFixture { empty, populated }

final _monthlyOffer = <String, dynamic>{
  'available': true,
  'period': 'monthly',
  'months': 1,
  'currency': 'CNY',
  'charge_currency': 'SGD',
  'price_cents': 3800,
  'recurring_price_cents': 3420,
  'handling_amount_cents': 0,
  'recurring_total_cents': 3420,
  'charge_amount_cents': 680,
  'first_total_cents': 1200,
  'first_charge_amount_cents': 240,
  'surplus_amount_cents': 2220,
  'surplus_credit_cents': 0,
  'quote_id': 9,
  'quote_expires_at': 4102444800,
  'gift_replacement': false,
  'switch_immediately': true,
  'next_charge_at': null,
};

MockClient _buildMockClient({
  required List<http.Request> requests,
  required bool Function() loginFails,
  _MockFixture fixture = _MockFixture.empty,
  List<Json>? orders,
}) {
  final orderRows =
      orders ??
      <Json>[
        {'trade_no': 'orderA', 'status': 0, 'total_amount': 1200},
      ];
  return MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/login')) {
      return http.Response(
        loginFails()
            ? '{"message":"PRIVATE_DO_NOT_RENDER"}'
            : '{"data":{"auth_data":"Bearer fixture"}}',
        loginFails() ? 401 : 200,
      );
    }
    dynamic data;
    if (path.endsWith('/user/info')) {
      data = {'email': 'client@example.com'};
    } else if (path.endsWith('/getSubscribe')) {
      data = fixture == _MockFixture.populated
          ? {
              'plan_id': 3,
              'plan': {'id': 3, 'name': '\u5168\u7403\u7545\u8054'},
              'u': 2147483648,
              'd': 8589934592,
              'transfer_enable': 107374182400,
              'subscribe_url': 'https://panel.example/s/PRIVATE_DO_NOT_RENDER',
              'token': 'PRIVATE_DO_NOT_RENDER',
              'uuid': 'UUID_DO_NOT_RENDER',
            }
          : {
              'plan_id': null,
              'u': 0,
              'd': 0,
              'transfer_enable': 0,
              'subscribe_url': 'https://panel.example/s/PRIVATE_DO_NOT_RENDER',
              'token': 'PRIVATE_DO_NOT_RENDER',
              'uuid': 'UUID_DO_NOT_RENDER',
            };
    } else if (path.endsWith('/server/fetch')) {
      data = fixture == _MockFixture.populated
          ? <Json>[
              {
                'id': 101,
                'name': 'Tokyo \u2013 Premium',
                'tags': ['Asia', 'Low Latency'],
                'rate': '1.0',
              },
              {
                'id': 102,
                'name': 'Singapore \u2013 Standard',
                'tags': ['Asia'],
                'rate': '0.5',
              },
              {
                'id': 103,
                'name': 'Frankfurt \u2013 Transit',
                'tags': ['Europe'],
                'rate': '1.0',
              },
            ]
          : <Json>[];
    } else if (path.endsWith('/plan/fetch')) {
      data = fixture == _MockFixture.populated
          ? [
              {
                'id': 3,
                'name': '\u5168\u7403\u7545\u8054',
                'month_price': 3800,
              },
              {'id': 1, 'name': 'Test Plan', 'month_price': 1200},
            ]
          : [
              {'id': 1, 'name': 'Test Plan', 'month_price': 1200},
            ];
    } else if (path.endsWith('/zolnit-stripe/plans')) {
      data = {
        'plans': [
          {
            'id': 3,
            'periods': [_monthlyOffer],
          },
        ],
      };
    } else if (path.endsWith('/zolnit-stripe/recurring-orders')) {
      orderRows.add({'trade_no': 'monthlyA', 'status': 0, 'total_amount': 0});
      data = {'trade_no': 'monthlyA'};
    } else if (path.endsWith('/zolnit-stripe/recurring-orders/monthlyA')) {
      data = {
        ..._monthlyOffer,
        'recurring': true,
        'trade_no': 'monthlyA',
        'payment_id': 1,
        'plan_id': 3,
        'total_cents': _monthlyOffer['recurring_total_cents'],
        'status': 0,
      };
    } else if (path.endsWith('/zolnit-stripe/subscribe')) {
      data = {
        'checkout_mode': 'hosted',
        'checkout_url': 'https://checkout.stripe.com/pay/monthlyA',
        'session_id': 'cs_test_fixture',
        'contract_id': 5,
      };
    } else if (path.endsWith('/order/detail')) {
      data = {'trade_no': 'monthlyA', 'total_amount': 0};
    } else if (path.endsWith('/order/check')) {
      data = 0;
    } else if (path.endsWith('/order/fetch')) {
      data = orderRows;
    } else if (path.endsWith('/order/save')) {
      data = 'orderA';
    } else if (path.endsWith('/getPaymentMethod')) {
      data = [
        {'id': 1, 'name': 'Stripe'},
      ];
    } else if (path.endsWith('/zolnit-stripe/config')) {
      data = {
        'enabled': true,
        'configured': true,
        'channels': [
          {'id': 1, 'name': 'Stripe', 'enabled': true, 'configured': true},
        ],
      };
    } else if (path.endsWith('/subscriptions')) {
      data = {
        'subscriptions': [
          {
            'id': 1,
            'plan_name': fixture == _MockFixture.populated
                ? '\u5168\u7403\u7545\u8054'
                : 'Existing Plan',
            'paid_through': 1795000000,
            'next_renewal_at': 1795000000,
            'can_cancel': true,
            'can_resume': false,
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
    return http.Response(
      jsonEncode({'data': data}),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
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

  testWidgets('signed-out brand screen is offline and validates input', (
    tester,
  ) async {
    await mount(tester);
    expect(requests, isEmpty);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey('zolnit-brand-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('zolnit-sign-in')));
    await tester.pump();
    expect(requests, isEmpty);
    expect(find.textContaining('valid email'), findsWidgets);
    await capture(tester, 'login-desktop-light');
  });

  testWidgets('signed-out desktop dark shows brand panel', (tester) async {
    await mount(tester, dark: true);
    expect(find.byKey(const ValueKey('zolnit-brand-panel')), findsOneWidget);
    await capture(tester, 'login-desktop-dark');
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
        findsWidgets,
      );
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await capture(tester, 'dashboard-desktop-light');
      await tester.tap(find.text('Plans').first);
      await tester.pumpAndSettle();
      expect(find.text('Test Plan'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
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
      await tester.tap(find.text('Choose plan'));
      await tester.pumpAndSettle();
      expect(find.text('Test Plan · ¥12.00'), findsOneWidget);
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
      await capture(tester, 'login-phone-dark');
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
    expect(find.text('\u6b22\u8fce\u56de\u6765'), findsOneWidget);
    await capture(tester, 'login-desktop-zh-light');
    await session.login('client@example.com', 'password123');
    await tester.pumpAndSettle();
    expect(
      find.text(
        '\u5f53\u524d\u8ba2\u9605\u6682\u65e0\u53ef\u7528\u8282\u70b9\u3002',
      ),
      findsWidgets,
    );
    await capture(tester, 'dashboard-desktop-zh-light');
  });

  group('populated zh-CN fixture', () {
    late ZolnitSessionController populatedSession;
    late ProviderContainer populatedContainer;
    late List<http.Request> populatedRequests;
    late Directory populatedPaths;
    late _Platform populatedPlatform;
    late List<Json> populatedOrders;
    final consents = <Json>[];
    var approveMonthly = true;

    setUp(() async {
      populatedPaths = await Directory.systemTemp.createTemp('zolnit-home-');
      await useAppPaths(populatedPaths);
      populatedRequests = [];
      populatedOrders = [
        {'trade_no': 'orderA', 'status': 0, 'total_amount': 1200},
      ];
      consents.clear();
      approveMonthly = true;
      Future<bool> consent(Json terms) async {
        consents.add(terms);
        return approveMonthly;
      }

      final api = XboardClient(
        origin: Uri.parse('https://panel.example'),
        client: _buildMockClient(
          requests: populatedRequests,
          loginFails: () => false,
          fixture: _MockFixture.populated,
          orders: populatedOrders,
        ),
      );
      populatedPlatform = _Platform();
      populatedSession = ZolnitSessionController(
        api: api,
        billing: ZolnitBillingClient(api),
        confirmRecurring: consent,
        checkout: CheckoutController(
          backend: XboardCheckoutBackend(api, confirmRecurring: consent),
          platform: populatedPlatform,
          allowedHttpsOrigins: {'https://checkout.stripe.com'},
          allowStripe: true,
        ),
      );
      populatedContainer = ProviderContainer(
        overrides: [
          zolnitSessionProvider.overrideWithValue(populatedSession),
          zolnitSyncProfileProvider.overrideWithValue(() async => null),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      globalState.container = populatedContainer;
      populatedContainer.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
    });

    tearDown(() async {
      populatedContainer.dispose();
      populatedSession.dispose();
      await populatedPaths.delete(recursive: true);
    });

    Future<void> signInPopulated() async {
      await populatedSession.login('client@example.com', 'password123');
      expect(
        populatedSession.authenticated,
        isTrue,
        reason: populatedSession.failure,
      );
    }

    Future<void> mountPopulated(
      WidgetTester tester, {
      bool phone = false,
      bool dark = false,
      Locale locale = const Locale('zh', 'CN'),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = phone
          ? const Size(390, 844)
          : const Size(1200, 850);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: populatedContainer,
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

    testWidgets('populated dashboard shows plan name and traffic in zh-CN', (
      tester,
    ) async {
      await signInPopulated();
      await populatedSession.refreshBilling();
      await mountPopulated(tester);
      expect(find.text('\u5168\u7403\u7545\u8054'), findsWidgets);
      expect(find.text('10 / 100 GB'), findsOneWidget);
      expect(find.textContaining('PRIVATE_DO_NOT_RENDER'), findsNothing);
      await capture(tester, 'dashboard-populated-zh-light');
    });

    testWidgets('populated plans show node metadata entries', (tester) async {
      await signInPopulated();
      await mountPopulated(tester);
      await tester.tap(find.text('\u5957\u9910').first);
      await tester.pumpAndSettle();
      expect(find.text('\u5168\u7403\u7545\u8054'), findsWidgets);
      expect(find.text('38'), findsOneWidget);
      await capture(tester, 'plans-populated-zh-light');
    });

    testWidgets('monthly enrollment shows the server quote before any order', (
      tester,
    ) async {
      await signInPopulated();
      await mountPopulated(tester);
      await tester.tap(find.text('\u5957\u9910').first);
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('zolnit-monthly-3-1'));
      expect(button, findsOneWidget);
      approveMonthly = false;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(consents.single['quote_id'], 9);
      expect(consents.single['first_total_cents'], 1200);
      expect(consents.single['switch_immediately'], isTrue);
      expect(
        populatedRequests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/recurring-orders'),
        ),
        isEmpty,
      );
      expect(populatedPlatform.opened, isEmpty);
    });

    testWidgets(
      'an approved quote creates the order and opens hosted checkout',
      (tester) async {
        await signInPopulated();
        await mountPopulated(tester);
        await tester.tap(find.text('\u5957\u9910').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('zolnit-monthly-3-1')));
        await tester.pumpAndSettle();
        final posts = populatedRequests
            .where(
              (r) =>
                  r.method == 'POST' && r.url.path.contains('/zolnit-stripe/'),
            )
            .toList();
        expect(posts.map((r) => r.url.path), [
          '/api/v1/zolnit-stripe/recurring-orders',
          '/api/v1/zolnit-stripe/subscribe',
        ]);
        expect(jsonDecode(posts.first.body), {
          'payment_id': 1,
          'plan_id': 3,
          'quote_id': 9,
          'consent': true,
        });
        expect(consents, hasLength(1));
        expect(populatedPlatform.opened.single.host, 'checkout.stripe.com');
        expect(find.text('monthlyA'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('populated nodes page renders server names', (tester) async {
      await signInPopulated();
      await mountPopulated(tester);
      await tester.tap(find.text('\u8282\u70b9').first);
      await tester.pumpAndSettle();
      expect(find.text('Tokyo \u2013 Premium'), findsOneWidget);
      expect(find.text('Frankfurt \u2013 Transit'), findsOneWidget);
      await capture(tester, 'nodes-populated-zh-light');
    });

    testWidgets('populated account page shows plan in zh-CN', (tester) async {
      await signInPopulated();
      await populatedSession.refreshBilling();
      await mountPopulated(tester);
      await tester.tap(find.text('\u8d26\u53f7').first);
      await tester.pumpAndSettle();
      expect(find.text('client@example.com'), findsOneWidget);
      expect(find.text('\u5168\u7403\u7545\u8054'), findsWidgets);
      expect(find.textContaining('UUID_DO_NOT_RENDER'), findsNothing);
      await capture(tester, 'account-populated-zh-light');
    });

    testWidgets(
      'connect stays disabled even with populated nodes in safe mode',
      (tester) async {
        await signInPopulated();
        await mountPopulated(tester);
        final button = tester.widget<ZolnitPowerButton>(
          find.byType(ZolnitPowerButton),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets('phone dark populated dashboard captures', (tester) async {
      await signInPopulated();
      await mountPopulated(tester, phone: true, dark: true);
      expect(find.text('\u5168\u7403\u7545\u8054'), findsWidgets);
      expect(find.byType(ZolnitBrand), findsOneWidget);
      await capture(tester, 'dashboard-populated-phone-dark');
    });
  });
}
