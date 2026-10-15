import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/compute.dart';
import 'package:fl_clash/common/l10n_labels.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tray/tray.dart';

import '../helpers/test_profiles.dart';

const _channel = MethodChannel('tray');

const _proxyGroup = Group(
  name: 'Proxy',
  type: GroupType.Selector,
  now: 'A',
  all: [
    Proxy(name: 'A', type: 'Direct'),
    Proxy(name: 'B', type: 'Direct'),
    Proxy(name: 'C', type: 'Direct'),
  ],
);

HotKeyAction _bind(HotAction action, PhysicalKeyboardKey key) {
  return HotKeyAction(
    action: action,
    key: key.usbHidUsage,
    modifiers: const {KeyboardModifier.control, KeyboardModifier.shift},
  );
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

TrayState _trayState({
  bool isStart = false,
  bool tunEnable = false,
  bool systemProxy = false,
  bool autoLaunch = false,
  bool showTrayTitle = false,
  bool safeMode = false,
  Mode mode = Mode.rule,
  List<Group> groups = const [],
  Map<HotAction, HotKeyAction> hotKeys = const {},
}) {
  return TrayState(
    mode: mode,
    port: 7890,
    autoLaunch: autoLaunch,
    systemProxy: systemProxy,
    tunEnable: tunEnable,
    isStart: isStart,
    groups: groups,
    selectedMap: const {},
    showTrayTitle: showTrayTitle,
    safeMode: safeMode,
    hotKeys: hotKeys,
  );
}

List<Map<Object?, Object?>> _items(MethodCall? call) {
  final menu = (call?.arguments as Map?)?['menu'] as List?;
  return menu?.cast<Map<Object?, Object?>>() ?? const [];
}

Map<Object?, Object?> _item(MethodCall? call, String label) {
  return _items(call).firstWhere((item) => item['label'] == label);
}

List<String> _labels(MethodCall? call) {
  return _items(call).map((item) => item['label']).whereType<String>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late ProviderContainer container;
  late AppTray tray;

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('tray_menu_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await AppLocalizations.load(const Locale('en'));
  });

  tearDownAll(() {
    // The shared system temp dir is not exclusively ours; another suite running
    // alongside this one can take the tree out from under the teardown, either
    // before the check or between the check and the delete.
    try {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls = [];
    tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    Tray.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  MethodCall? showCall() {
    for (final call in calls.reversed) {
      if (call.method == 'show') {
        return call;
      }
    }
    return null;
  }

  Future<void> update(TrayState trayState, {AppTray? on}) {
    return (on ?? tray).update(
      trayState: trayState,
      traffic: const Traffic(),
      read: container.read,
    );
  }

  test(
    'SystemAction.updateTray builds the menu without reading itself',
    () async {
      globalState.container = container;
      trayPort = tray;
      addTearDown(() => trayPort = null);

      await container.read(systemActionProvider.notifier).updateTray();

      expect(showCall(), isNotNull);
      expect(_labels(showCall()), contains(currentAppLocalizations.exit));
    },
  );

  test('builds the stopped menu without the running-only toggles', () async {
    await update(_trayState());

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.show));
    expect(labels, contains(l10n.start));
    expect(labels, contains(l10n.autoLaunch));
    expect(labels, contains(l10n.copyEnvVar));
    expect(labels, contains(l10n.exit));
    expect(labels, isNot(contains(l10n.tun)));
    expect(labels, isNot(contains(l10n.systemProxy)));
  });

  test('adds TUN and system proxy toggles once the core is running', () async {
    await update(_trayState(isStart: true));

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.stop), reason: 'start flips to stop');
    expect(labels, contains(l10n.tun));
    expect(labels, contains(l10n.systemProxy));
  });

  group('safe mode', () {
    test('keeps the full menu', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final labels = _labels(showCall());
      final l10n = currentAppLocalizations;
      expect(labels, contains(l10n.stop));
      expect(labels, contains(l10n.tun));
      expect(labels, contains(l10n.systemProxy));
      expect(labels, contains(l10n.copyEnvVar));
    });

    test('names the mode in the tooltip and ships the safe icon', () async {
      await update(_trayState(isStart: true, safeMode: true));

      final arguments = showCall()!.arguments as Map;
      final l10n = currentAppLocalizations;
      expect(arguments['toolTip'], '$appName (${l10n.safeMode})');
      final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
      final base = reps.firstWhere((rep) => rep['scale'] == 1.0);
      expect(
        base['bytes'],
        base64Encode(
          File('assets/images/tray/macos/status_4.png').readAsBytesSync(),
        ),
      );
    });
  });

  test('offers every outbound mode as a menu entry', () async {
    await update(_trayState(mode: Mode.global));

    final checkedModes = _items(showCall())
        .where((item) => item['checked'] == true)
        .map((item) => item['label'])
        .toList();
    expect(checkedModes, contains(Intl.message(Mode.global.name)));
  });

  test('sends icon, tooltip and menu in a single show call', () async {
    await update(_trayState(isStart: true, tunEnable: true));

    final showCalls = calls.where((call) => call.method == 'show').toList();
    expect(showCalls, hasLength(1));

    final arguments = showCalls.single.arguments as Map;
    expect(arguments['toolTip'], appName);
    expect(arguments['menu'], isNotEmpty);
    final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
    expect(reps.map((rep) => rep['scale']), containsAll([1.0, 2.0, 3.0, 4.0]));
    expect(reps.map((rep) => rep['bytes']), everyElement(isNotEmpty));
    expect((arguments['icon'] as Map)['isTemplate'], isTrue);
  });

  test('skips the platform call when the tray state is unchanged', () async {
    await update(_trayState(isStart: true));
    await update(_trayState(isStart: true));

    expect(calls.where((call) => call.method == 'show'), hasLength(1));
  });

  test('menu item ids are stable across identical rebuilds', () async {
    await update(_trayState());
    final first = _items(showCall()).map((item) => item['id']).toList();

    Tray.instance.resetForTesting();
    calls.clear();

    await update(_trayState());
    final second = _items(showCall()).map((item) => item['id']).toList();

    expect(second, first);
    expect(first.first, 1024);
  });

  test('group submenus carry their proxies as nested items', () async {
    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            all: [Proxy(name: 'A', type: 'Direct')],
          ),
        ],
      ),
    );

    final submenu = _items(
      showCall(),
    ).firstWhere((item) => item['label'] == 'Proxy');
    expect(submenu['label'], 'Proxy');
    final children = (submenu['items'] as List).cast<Map<Object?, Object?>>();
    expect(children.map((item) => item['label']), contains('A'));
  });

  test('shows each bound hotkey dimmed beside its entry', () async {
    await update(
      _trayState(
        isStart: true,
        hotKeys: {
          HotAction.view: _bind(HotAction.view, PhysicalKeyboardKey.keyV),
          HotAction.globalMode: _bind(
            HotAction.globalMode,
            PhysicalKeyboardKey.keyG,
          ),
          HotAction.tun: _bind(HotAction.tun, PhysicalKeyboardKey.keyT),
        },
      ),
    );

    final l10n = currentAppLocalizations;
    final call = showCall();
    expect(_item(call, l10n.show)['detail'], '⌃⇧V');
    expect(_item(call, Mode.global.label)['detail'], '⌃⇧G');
    expect(_item(call, l10n.tun)['detail'], '⌃⇧T');
    expect(_item(call, l10n.exit), isNot(contains('detail')));
    expect(_item(call, Mode.rule.label), isNot(contains('detail')));
  });

  test(
    'group submenus show the delay of the selection and of each proxy',
    () async {
      final url = container.read(appSettingProvider).testUrl;
      container.read(delayDataSourceProvider.notifier).value = {
        url: {'A': 120, 'B': -1, 'C': -2},
      };
      const group = Group(
        name: 'Proxy',
        type: GroupType.URLTest,
        now: 'A',
        all: [
          Proxy(name: 'A', type: 'Direct'),
          Proxy(name: 'B', type: 'Direct'),
          Proxy(name: 'C', type: 'Direct'),
          Proxy(name: 'D', type: 'Direct'),
        ],
      );
      container.read(groupsProvider.notifier).value = [group];
      await update(_trayState(groups: [group.copyWith(now: '')]));

      final submenu = _item(showCall(), 'Proxy');
      expect(submenu['detail'], '120');
      expect(submenu['sublabel'], 'A');
      final children = (submenu['items'] as List).cast<Map<Object?, Object?>>();
      expect(
        children.where((item) => item['checked'] == true).single['label'],
        'A',
      );
      expect(
        children
            .where((item) => item['type'] == 'checkbox')
            .map((item) => item['detail']),
        [
          '120',
          currentAppLocalizations.timeout,
          currentAppLocalizations.delayFailed,
          null,
        ],
      );
    },
  );

  test('a delay test entry follows the groups', () async {
    await update(
      _trayState(
        groups: [_proxyGroup],
        hotKeys: {
          HotAction.delayTest: _bind(
            HotAction.delayTest,
            PhysicalKeyboardKey.keyD,
          ),
        },
      ),
    );

    final items = _items(showCall());
    final index = items.indexWhere((item) => item['label'] == 'Proxy');
    expect(items[index + 1]['label'], HotAction.delayTest.label);
    expect(items[index + 1]['detail'], '⌃⇧D');
  });

  test(
    'the tray proxy selection setting hides groups on every platform',
    () async {
      container
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayProxySelection: false));
      await update(_trayState(groups: [_proxyGroup]));
      expect(
        _items(showCall()).where((item) => item['label'] == 'Proxy'),
        isEmpty,
      );
      expect(_labels(showCall()), isNot(contains(HotAction.delayTest.label)));
    },
  );

  test(
    'keyed delay batches update aliases in every group without rebuilding',
    () async {
      const other = Group(
        name: 'Other',
        type: GroupType.Selector,
        all: [
          Proxy(name: 'A', type: 'Direct'),
          Proxy(name: 'Proxy', type: 'Selector'),
        ],
      );
      container.read(groupsProvider.notifier).value = [_proxyGroup, other];
      final url = container.read(appSettingProvider).testUrl;
      await update(_trayState(groups: [_proxyGroup, other]));
      calls.clear();
      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(Delay(name: 'A', url: url, value: 900));
      await tray.updateDelays(read: container.read);
      expect(calls.map((call) => call.method), ['updateMenuItems']);
      final updates = ((calls.single.arguments as Map)['updates'] as List)
          .cast<Map>();
      expect(updates, hasLength(3));
      expect(updates.map((item) => item['sublabel']), everyElement('900 ms'));
      expect(
        updates.map((item) => item['sublabelStyle']),
        everyElement('warning'),
      );

      calls.clear();
      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(Delay(name: 'A', url: url, value: 80));
      await tray.updateDelays(read: container.read);
      expect(calls.map((call) => call.method), ['updateMenuItems']);
      expect(
        ((calls.single.arguments as Map)['updates'] as List).cast<Map>().map(
          (item) => item['sublabel'],
        ),
        everyElement('80 ms'),
      );
    },
  );

  test('each proxy submenu offers a persistent delay test action', () async {
    await update(_trayState(groups: [_proxyGroup]));
    final children = (_item(showCall(), 'Proxy')['items'] as List).cast<Map>();
    expect(children.first['keepsMenuOpen'], isTrue);
    expect(children.first['key'], startsWith('delay-test:'));
  });

  test(
    'pending tests keep their measured delay and restore it on finish',
    () async {
      final url = container.read(appSettingProvider).testUrl;
      final key = delayTestKey(url, 'A');
      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(Delay(name: 'A', url: url, value: 0));
      await update(_trayState(groups: [_proxyGroup]));
      final children = (_item(showCall(), 'Proxy')['items'] as List)
          .cast<Map>();
      final proxy = children.singleWhere((item) => item['label'] == 'A');
      expect(proxy['detail'], '0');
      expect(proxy['sublabel'], '0 ms');

      container.read(pendingDelayTestsProvider.notifier).apply(acquired: [key]);
      calls.clear();
      await tray.updateDelays(read: container.read);
      expect(
        ((calls.single.arguments as Map)['updates'] as List)
            .cast<Map>()
            .single['sublabel'],
        '...',
      );
      expect(container.read(delayDataSourceProvider)[url]?['A'], 0);

      container.read(pendingDelayTestsProvider.notifier).apply(released: [key]);
      calls.clear();
      await tray.updateDelays(read: container.read);
      expect(
        ((calls.single.arguments as Map)['updates'] as List)
            .cast<Map>()
            .single['sublabel'],
        '0 ms',
      );
    },
  );

  group('a platform that is not macOS', () {
    late AppTray windows;

    setUp(() {
      windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    });

    test(
      'gets a plain icon and proxy submenus without the macOS speed toggle',
      () async {
        await update(
          _trayState(
            isStart: true,
            groups: [
              const Group(
                name: 'Proxy',
                type: GroupType.Selector,
                all: [Proxy(name: 'A', type: 'Direct')],
              ),
            ],
          ),
          on: windows,
        );

        final arguments = showCall()!.arguments as Map;
        expect((arguments['icon'] as Map)['isTemplate'], isFalse);
        expect(
          _items(showCall()).where((item) => item['label'] == 'Proxy'),
          hasLength(1),
        );
        expect(
          _labels(showCall()),
          isNot(contains(currentAppLocalizations.speedStatistics)),
        );
        expect(_labels(showCall()), contains(HotAction.delayTest.label));
      },
    );

    test('joins modifiers with + in the hotkey hints', () async {
      await update(
        _trayState(
          hotKeys: {
            HotAction.view: _bind(HotAction.view, PhysicalKeyboardKey.keyV),
          },
        ),
        on: windows,
      );

      expect(
        _item(showCall(), currentAppLocalizations.show)['detail'],
        'Ctrl+Shift+V',
      );
    });

    test('never pushes a tray title', () async {
      await windows.updateTitle(showTrayTitle: true, traffic: const Traffic());

      expect(calls.where((call) => call.method == 'setTitle'), isEmpty);
    });
  });
}
