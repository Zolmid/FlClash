import 'dart:convert';

import 'package:fl_clash/common/ios_device_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zolnit_client/zolnit_client.dart';

const _tag = 'v1.1.9';
const _origin = 'https://link.zolmid.com';
final _id = 'a' * 32;
final _manifest =
    '$_origin/api/v1/zolnit/client/apple/ota/${'b' * 43}/manifest.plist';
String _handoff(String manifest) =>
    'itms-services://?action=download-manifest&url=${Uri.encodeComponent(manifest)}';
final _device = {'device_id': _id, 'product': 'iPhone17,1'};
final _job = {
  'device_id': _id,
  'job_id': 'job',
  'release_tag': _tag,
  'build': 2026111406,
};

http.Response _json(Object? data) =>
    http.Response(jsonEncode({'data': data}), 200);

class _Fixture {
  _Fixture({
    this.offerDevices = false,
    this.ticket,
    this.queuedFirst = false,
    this.changeAccount = false,
    this.rateLimited = false,
    this.canLaunch,
  }) {
    api = XboardClient(
      origin: Uri.parse(_origin),
      client: MockClient((request) async {
        final path = request.url.path;
        paths.add(path.split('/').last);
        if (path.endsWith('/app-binding')) {
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {'device_id': _id});
            return _json({'device': _device});
          }
          return _json({
            'device': offerDevices ? null : _device,
            'devices': [_device],
          });
        }
        if (path.endsWith('/config')) {
          return _json({
            'latest_published_release_tag': _tag,
            'latest_published_build': 2026111406,
            'release_tag': _tag,
            'build': 2026111406,
            'archive_preparing': false,
          });
        }
        if (path.endsWith('/builds')) return _json(_job);
        if (path.endsWith('/status')) {
          checks++;
          if (queuedFirst && checks == 1) {
            return _json({..._job, 'status': 'queued'});
          }
          return _json({..._job, 'status': 'ready'});
        }
        if (path.endsWith('/install-ticket')) {
          if (rateLimited) {
            return http.Response('', 429, headers: {'retry-after': '45'});
          }
          if (changeAccount) api.setAuthorization('Bearer second');
          return _json({
            ..._job,
            'expires_at': 2000000000,
            'itms_services_url': ticket ?? _handoff(_manifest),
          });
        }
        throw StateError('Unexpected route');
      }),
    )..setAuthorization('Bearer first');
    updater = IosDeviceUpdater(
      api: api,
      isCurrent: () => true,
      realtimeHealthy: () => false,
      canLaunch: canLaunch,
      selectDevice: (devices) async {
        selected++;
        return devices.single.id;
      },
      launch: (uri) async {
        launched.add(uri.toString());
        return true;
      },
      fallbackInterval: Duration.zero,
      now: () => DateTime.utc(2026, 11, 14),
    );
  }

  final bool offerDevices, queuedFirst, changeAccount, rateLimited;
  final String? ticket;
  final bool Function()? canLaunch;
  final paths = <String>[], launched = <String>[];
  int checks = 0, selected = 0;
  late final XboardClient api;
  late final IosDeviceUpdater updater;

  Future<IosDeviceUpdateResult> install() => updater.install(
    releaseTag: _tag,
    installedRelease: '1.1.8',
    installedBuild: 2026111405,
  );
}

void main() {
  test('reuse binding, wait for the matching job, and hand off once', () async {
    final f = _Fixture(queuedFirst: true);
    addTearDown(f.api.close);
    expect(await f.install(), IosDeviceUpdateResult.handedOff);
    expect(f.selected, 0);
    expect(f.paths, [
      'app-binding',
      'config',
      'builds',
      'status',
      'status',
      'install-ticket',
    ]);
    expect(f.launched, [_handoff(_manifest)]);
  });

  test('explicit unbound choice is saved before requesting a build', () async {
    final f = _Fixture(offerDevices: true);
    addTearDown(f.api.close);
    expect(await f.install(), IosDeviceUpdateResult.handedOff);
    expect(f.selected, 1);
    expect(f.paths.take(3), ['app-binding', 'app-binding', 'config']);
  });

  test('wait for foreground before minting a ticket', () async {
    var checks = 0;
    final f = _Fixture(canLaunch: () => checks++ > 0);
    addTearDown(f.api.close);
    expect(await f.install(), IosDeviceUpdateResult.handedOff);
    expect(f.paths.where((p) => p == 'status'), hasLength(2));
    expect(f.paths.where((p) => p == 'install-ticket'), hasLength(1));
  });

  test('reject an off-site or parameter-injected manifest', () async {
    for (final ticket in [
      _handoff(_manifest.replaceFirst(_origin, 'https://example.test')),
      _handoff('$_manifest?unexpected=1'),
      '${_handoff(_manifest)}&action=bad',
    ]) {
      final f = _Fixture(ticket: ticket);
      addTearDown(f.api.close);
      expect(await f.install(), IosDeviceUpdateResult.useWebsite);
      expect(f.launched, isEmpty);
    }
  });

  test(
    'sign-out or account switch during ticket fetch prevents launch',
    () async {
      final f = _Fixture(changeAccount: true);
      addTearDown(f.api.close);
      expect(await f.install(), IosDeviceUpdateResult.cancelled);
      expect(f.launched, isEmpty);
    },
  );

  test(
    '429 respects the cooldown without reissuing the install ticket',
    () async {
      final f = _Fixture(rateLimited: true);
      addTearDown(f.api.close);
      expect(await f.install(), IosDeviceUpdateResult.throttled);
      expect(f.updater.retryAt, DateTime.utc(2026, 11, 14, 0, 0, 45));
      expect(f.paths.where((p) => p == 'install-ticket'), hasLength(1));
      expect(f.launched, isEmpty);
    },
  );
}
