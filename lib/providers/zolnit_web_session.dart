import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'zolnit.dart';

final zolnitWebSessionProvider = Provider<ZolnitWebSessionCoordinator>((ref) {
  final coordinator = ZolnitWebSessionCoordinator(
    session: ref.read(zolnitSessionProvider),
    canAuthorize: Platform.isAndroid || Platform.isIOS || Platform.isWindows,
    browser: Platform.isAndroid || Platform.isIOS
        ? _MobileWebSessionBrowser()
        : _DesktopWebSessionBrowser(),
    fallback: (uri) async {
      for (final mode in [
        LaunchMode.inAppBrowserView,
        LaunchMode.externalApplication,
      ]) {
        try {
          if (await supportsLaunchMode(mode) &&
              await launchUrl(uri, mode: mode)) {
            return true;
          }
        } catch (_) {}
      }
      return false;
    },
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

class _MobileWebSessionBrowser implements ZolnitWebSessionBrowser {
  static const _channel = MethodChannel('com.zolmid.zolnit/web_session');
  @override
  Future<bool> open(String code, String destination) async =>
      await _channel.invokeMethod<bool>('open', {
        'code': code,
        'destination': destination,
      }) ??
      false;
  @override
  Future<void> close() async {
    final closed = await _channel
        .invokeMethod<bool>('close')
        .timeout(const Duration(seconds: 5));
    if (closed != true) throw StateError('Web session did not close');
  }
}

class _DesktopWebSessionBrowser implements ZolnitWebSessionBrowser {
  Webview? _window;
  Directory? _profile;
  int _epoch = 0;

  @override
  Future<bool> open(String code, String destination) async {
    final epoch = _epoch;
    if (!await WebviewWindow.isWebviewAvailable() || epoch != _epoch) {
      return false;
    }
    final profile = await Directory.systemTemp.createTemp(
      'zolnit-web-session-',
    );
    if (epoch != _epoch) {
      await profile.delete(recursive: true);
      return false;
    }
    _profile = profile;
    try {
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'ZolNit',
          windowWidth: 900,
          windowHeight: 720,
          windows: WindowsWebviewOptions(
            userDataFolder: path.join(profile.path, 'WebView2'),
            denyCameraAndMicrophone: true,
          ),
        ),
      );
      if (epoch != _epoch) {
        await window.close();
        return false;
      }
      _window = window;
      await window.setOnUrlRequestCallback((value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.scheme == 'https' &&
            uri.host == 'link.zolmid.com' &&
            uri.port == 443 &&
            uri.userInfo.isEmpty;
      });
      await window.addScriptToExecuteOnDocumentCreated('''
        if (window.top === window && window.location.href === ${jsonEncode(zolnitWebLanding)}) {
          window.__ZolnitWebSessionNative = ${jsonEncode([code, destination])};
        }
      ''');
      final loaded = Completer<bool>();
      var sawLanding = false;
      void navigationChanged() {
        final state = window.navigationState.value;
        if (state.url == zolnitWebLanding) sawLanding = true;
        if (!loaded.isCompleted &&
            !state.isLoading &&
            sawLanding &&
            (state.url == zolnitWebLanding ||
                state.url == '$zolnitWebOrigin$destination')) {
          loaded.complete(true);
        }
      }

      window.navigationState.addListener(navigationChanged);
      final errors = window.onLoadError.listen((error) {
        if (!loaded.isCompleted && error.url == zolnitWebLanding) {
          loaded.complete(false);
        }
      });
      unawaited(
        window.onClose.then((_) async {
          if (!loaded.isCompleted) loaded.complete(false);
          if (identical(_window, window)) _window = null;
          await _deleteProfile(profile);
        }),
      );
      if (epoch != _epoch) {
        await window.close();
        return false;
      }
      await window.launch(zolnitWebLanding, triggerOnUrlRequestEvent: false);
      final success = await loaded.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
      window.navigationState.removeListener(navigationChanged);
      await errors.cancel();
      if (!success && epoch == _epoch) await close();
      return success && epoch == _epoch;
    } catch (_) {
      await close();
      return false;
    }
  }

  Future<void> _deleteProfile(Directory profile) async {
    if (identical(_profile, profile)) _profile = null;
    try {
      if (await profile.exists()) await profile.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    _epoch++;
    final window = _window;
    _window = null;
    if (window != null) {
      try {
        await window.close();
      } catch (_) {}
    }
    final profile = _profile;
    if (profile != null) await _deleteProfile(profile);
  }
}
