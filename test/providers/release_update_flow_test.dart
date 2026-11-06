import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_client.dart';
import 'package:fl_clash/common/app_update_status.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/app_paths.dart';

class _ReleaseServer implements HttpClientAdapter {
  var downloads = 0, checks = 0;
  var version = '1.0.1', contents = 'abc';
  bool disabled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelled,
  ) async {
    final uri = options.uri;
    expect(uri.origin, 'https://link.zolmid.com');
    final name = 'ZolNit-$version-android-arm64-v8a.apk';
    if (uri.path == '/client/releases.json') {
      checks++;
      return ResponseBody.fromString(
        jsonEncode({
          'schema_version': 1,
          'app_id': 'com.zolmid.zolnit',
          'updates_enabled': !disabled,
          'releases': [
            if (!disabled)
              {
                'tag': 'v$version',
                'notes': 'Faster startup',
                'assets': [
                  {
                    'name': name,
                    'url': '${uri.origin}/client/downloads/v$version/$name',
                    'size': 3,
                    'sha256':
                        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
                  },
                ],
              },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    expect(uri.path, '/client/downloads/v$version/$name');
    downloads++;
    return ResponseBody.fromString(
      contents,
      200,
      headers: {
        Headers.contentLengthHeader: ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'published release stages verified bytes, cashier/background exit cannot install Android, corrupt update offers a notice',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'zolnit-release-flow-',
      );
      addTearDown(() => root.delete(recursive: true));
      await useAppPaths(root);
      globalState.packageInfo = PackageInfo(
        appName: 'ZolNit',
        packageName: 'com.zolmid.zolnit',
        version: '1.0.0',
        buildNumber: '100',
      );
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final server = _ReleaseServer(),
          old = appUpdateClient.dio.httpClientAdapter;
      appUpdateClient.dio.httpClientAdapter = server;
      addTearDown(() => appUpdateClient.dio.httpClientAdapter = old);
      final updater = scope.read(commonActionProvider.notifier)
        ..detectAppUpdateTarget = () async =>
            const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a');
      AppUpdateStatus status() => scope.read(appUpdateStatusProvider);
      await updater.autoCheckUpdate();
      expect(status().phase, AppUpdatePhase.staged);
      expect(status().applyMode, AppUpdateApplyMode.userAction);
      final pkg = root
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.apk'));
      expect(await pkg.readAsString(), 'abc');
      await updater.applyStagedAppUpdateOnExit();
      expect(status().phase, AppUpdatePhase.staged);
      await updater.notifyAppUpdateHint(version: '1.0.1');
      expect(status().phase, AppUpdatePhase.staged);
      expect(server.downloads, 1);
      server.version = '1.0.2';
      server.contents = 'bad';
      await updater.notifyAppUpdateHint(version: '1.0.2');
      expect(status().phase, AppUpdatePhase.failed);
      expect(status().release?.tag, 'v1.0.2');
      expect(
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
      server.disabled = true;
      await updater.notifyAppUpdateHint(version: '1.0.3');
      expect(status().phase, AppUpdatePhase.announcement);
      expect(status().release?.tag, 'v1.0.3');
    },
  );
}
