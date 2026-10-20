import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _overrides = ProfileOverrides(
  tun: ProfileTun(
    mtu: 1400,
    disableIcmpForwarding: true,
    excludeInterface: ['docker0'],
  ),
  tunOverrideKeys: {
    TunOverrideKey.mtu,
    TunOverrideKey.disableIcmpForwarding,
    TunOverrideKey.excludeInterface,
  },
);

Future<YamlMap> _tunOf({
  required Map<String, dynamic> rawConfig,
  ProfileOverrides overrides = _overrides,
  bool bypassPrivateRoute = false,
}) async {
  final result = await makeRealProfileTask(
    MakeRealProfileState(
      profilesPath: '/profiles',
      profileId: 1,
      rawConfig: rawConfig,
      realPatchConfig: const PatchClashConfig(),
      overrides: overrides,
      bypassPrivateRoute: bypassPrivateRoute,
      appendSystemDns: false,
      proxyGroups: const [],
      rules: const [],
      addedRules: const [],
      defaultUA: 'FlClash-Test',
    ),
  );
  final config = loadYaml(result.yaml) as YamlMap;
  return config['tun'] as YamlMap;
}

void main() {
  test('returns the same effective TUN metadata that it writes', () async {
    final result = await makeRealProfileTask(
      const MakeRealProfileState(
        profilesPath: '/profiles',
        profileId: 1,
        rawConfig: {
          'tun': {
            'mtu': 1600,
            'congestion-controller': 'bbr3',
            'recvmsgx': false,
            'sendmsgx': true,
            'disable-icmp-forwarding': true,
            'route-address': ['10.0.0.0/8'],
            'route-exclude-address': ['10.1.0.0/16'],
          },
        },
        realPatchConfig: PatchClashConfig(),
        overrides: ProfileOverrides(
          tun: ProfileTun(mtu: 1400, sendMsgX: false),
          tunOverrideKeys: {TunOverrideKey.mtu, TunOverrideKey.sendMsgX},
        ),
        appendSystemDns: false,
        proxyGroups: [],
        rules: [],
        addedRules: [],
        defaultUA: 'FlClash-Test',
      ),
    );
    final config = loadYaml(result.yaml) as YamlMap;
    final tun = config['tun'] as YamlMap;
    expect(result.tun.mtu, tun['mtu']);
    expect(result.tun.mtu, 1400);
    expect(result.tun.congestionController, 'bbr3');
    expect(result.tun.recvMsgX, isFalse);
    expect(result.tun.sendMsgX, isFalse);
    expect(result.tun.disableIcmpForwarding, isTrue);
    expect(result.tun.routeAddress, ['10.0.0.0/8']);
    expect(result.tun.routeExcludeAddress, ['10.1.0.0/16']);
  });

  test('writes the selected keys beside the network settings', () async {
    final tun = await _tunOf(rawConfig: {});

    expect(tun['disable-icmp-forwarding'], true);
    expect(tun['exclude-interface'], ['docker0']);
    expect(tun['mtu'], 1400);
  });

  test('replaces the same keys of the profile and keeps the rest', () async {
    final tun = await _tunOf(
      rawConfig: {
        'tun': {
          'exclude-interface': ['eth1'],
          'include-uid': [1000],
        },
      },
    );

    expect(tun['exclude-interface'], ['docker0']);
    expect(tun['include-uid'], [1000]);
  });

  test('hijacks every port 53 query over the profile unless a key is '
      'picked', () async {
    const profileHijack = {
      'tun': {
        'dns-hijack': ['198.18.0.2:53'],
      },
    };
    final tun = await _tunOf(
      rawConfig: profileHijack,
      overrides: const ProfileOverrides(),
    );
    final picked = await _tunOf(
      rawConfig: profileHijack,
      overrides: const ProfileOverrides(
        tun: ProfileTun(dnsHijack: ['tcp://any:53']),
        tunOverrideKeys: {TunOverrideKey.dnsHijack},
      ),
    );

    expect(tun['dns-hijack'], defaultDnsHijack);
    expect(picked['dns-hijack'], ['tcp://any:53']);
  });

  test(
    'excludes private ranges after the routes the profile excludes',
    () async {
      final tun = await _tunOf(
        rawConfig: {
          'tun': {
            'route-exclude-address': ['100.64.0.0/10'],
          },
        },
        overrides: const ProfileOverrides(),
        bypassPrivateRoute: true,
      );

      expect(tun['route-exclude-address'], [
        '100.64.0.0/10',
        ...privateRouteAddress,
      ]);
    },
  );

  test('leaves the profile alone without picked keys', () async {
    final tun = await _tunOf(
      rawConfig: {
        'tun': {
          'mtu': 1500,
          'exclude-interface': ['eth1'],
        },
      },
      overrides: const ProfileOverrides(
        tun: ProfileTun(disableIcmpForwarding: true),
      ),
    );

    expect(tun['mtu'], 1500);
    expect(tun['exclude-interface'], ['eth1']);
    expect(tun.containsKey('disable-icmp-forwarding'), isFalse);
  });
}
