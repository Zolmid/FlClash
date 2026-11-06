import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../common/link.dart';
import 'zolnit.dart';
import 'zolnit_native_renewal.dart';

final zolnitRegistrationProvider = Provider<ZolnitRegistrationCoordinator>((
  ref,
) {
  final coordinator = ZolnitRegistrationCoordinator(
    session: ref.read(zolnitSessionProvider),
    store: SecureZolnitRegistrationAttemptStore(
      storage: ref.read(zolnitSecureStorageProvider),
    ),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

abstract interface class ZolnitRegistrationBrowser {
  Future<bool> open(
    Uri registration, {
    required ValueChanged<Uri> onReturn,
    required VoidCallback onClosed,
  });

  Future<void> close();
}

abstract interface class ZolnitRegistrationAttemptStore {
  Future<ZolnitRegistrationAttempt?> read();

  Future<void> write(ZolnitRegistrationAttempt attempt);

  Future<void> clear();
}

class SecureZolnitRegistrationAttemptStore
    implements ZolnitRegistrationAttemptStore {
  SecureZolnitRegistrationAttemptStore({required FlutterSecureStorage storage})
    : _storage = storage;

  static const _key = 'zolnit.registration.attempt.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _key);

  @override
  Future<ZolnitRegistrationAttempt?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) return null;
      return ZolnitRegistrationAttempt.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(ZolnitRegistrationAttempt attempt) =>
      _storage.write(key: _key, value: jsonEncode(attempt.toJson()));
}

class ZolnitRegistrationCoordinator extends ChangeNotifier {
  ZolnitRegistrationCoordinator({
    required this.session,
    required this.store,
    ZolnitRegistrationBrowser? browser,
    List<int> Function(int length)? randomBytes,
  }) : _browser = browser ?? _registrationBrowser(),
       _randomBytes = randomBytes ?? _secureBytes {
    _accountGeneration = session.accountGeneration;
    session.addListener(_sessionChanged);
  }

  static const _ceremonyLifetime = Duration(minutes: 30);

  final ZolnitSessionController session;
  final ZolnitRegistrationAttemptStore store;
  final ZolnitRegistrationBrowser _browser;
  final List<int> Function(int length) _randomBytes;
  ZolnitRegistrationAttempt? _active;
  Timer? _expiration;
  late int _accountGeneration;
  bool _disposed = false;
  bool _opening = false;
  String? _claimedState;

  Future<Uri> begin() async {
    final generation = session.accountGeneration;
    final verifier = _base64Url(_randomBytes(32));
    final state = _base64Url(_randomBytes(32));
    final challenge = _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
    final registration = Uri.parse(
      'https://link.zolmid.com',
    ).replace(fragment: '/register?sso_challenge=$challenge&sso_state=$state');
    final attempt = ZolnitRegistrationAttempt(
      registration: registration,
      state: state,
      verifier: verifier,
      expiresAt: DateTime.now().add(_ceremonyLifetime),
    );
    try {
      await _storage(store.write(attempt));
    } catch (_) {
      throw const ClientFailure('storage_unavailable');
    }
    if (_disposed ||
        generation != session.accountGeneration ||
        session.authenticated) {
      throw const ClientFailure('superseded');
    }
    _setActive(attempt);
    return registration;
  }

  Future<void> restore() async {
    if (_active != null || _disposed || session.authenticated) return;
    final generation = session.accountGeneration;
    ZolnitRegistrationAttempt? attempt;
    try {
      attempt = await _storage(store.read());
    } catch (_) {
      session.reportSignInFailure('storage_unavailable');
      return;
    }
    if (attempt == null ||
        _disposed ||
        _active != null ||
        session.authenticated ||
        generation != session.accountGeneration ||
        attempt.state == _claimedState) {
      return;
    }
    if (!attempt.isValid || !attempt.expiresAt.isAfter(DateTime.now())) {
      try {
        await _storage(store.clear());
      } catch (_) {
        session.reportSignInFailure('storage_unavailable');
      }
      return;
    }
    _setActive(attempt);
  }

  Future<bool> start() async {
    if (_opening || _disposed || session.authenticated) return false;
    _opening = true;
    try {
      if (_active != null) {
        await cancel();
        await _browser.close();
      }
      final registration = await begin();
      final launched = await _browser.open(
        registration,
        onReturn: (uri) => unawaited(accept(uri)),
        onClosed: () => unawaited(cancel(registration)),
      );
      if (!launched) {
        await cancel(registration);
        session.reportSignInFailure('registration_browser_unavailable');
      }
      return launched;
    } catch (error) {
      await cancel();
      if (!_disposed &&
          !(error is ClientFailure && error.code == 'superseded')) {
        session.reportSignInFailure(
          error is ClientFailure
              ? error.code
              : 'registration_browser_unavailable',
        );
      }
      return false;
    } finally {
      _opening = false;
    }
  }

  Future<bool> accept(Uri uri) async {
    final result = _registrationReturn(uri);
    if (result == null || _disposed || session.authenticated) return false;
    final generation = session.accountGeneration;
    await restore();
    final attempt = _active;
    if (_disposed ||
        session.authenticated ||
        attempt == null ||
        result.state != attempt.state ||
        result.state == _claimedState ||
        !attempt.expiresAt.isAfter(DateTime.now()) ||
        session.accountGeneration != generation ||
        session.accountGeneration != _accountGeneration) {
      return false;
    }
    _claimedState = result.state;
    await _clearActive();
    if (_disposed ||
        session.authenticated ||
        session.accountGeneration != _accountGeneration) {
      return false;
    }
    await session.exchangeRegistration(result.code, attempt.verifier);
    try {
      await _browser.close();
    } catch (_) {
      // A system browser may already have closed itself on return.
    }
    return session.authenticated;
  }

  Future<void> cancel([Uri? registration]) async {
    final active = _active;
    if (active == null ||
        (registration != null && registration != active.registration)) {
      return;
    }
    await _clearActive();
  }

  void _setActive(ZolnitRegistrationAttempt attempt) {
    _expiration?.cancel();
    _accountGeneration = session.accountGeneration;
    _active = attempt;
    _expiration = Timer(
      attempt.expiresAt.difference(DateTime.now()),
      () => unawaited(cancel(attempt.registration)),
    );
    notifyListeners();
  }

  Future<void> _clearActive({bool notify = true}) async {
    if (_active == null) return;
    _expiration?.cancel();
    _expiration = null;
    _active = null;
    if (notify && !_disposed) notifyListeners();
    try {
      await _storage(store.clear());
    } catch (_) {
      if (!_disposed) session.reportSignInFailure('storage_unavailable');
    }
  }

  Future<T> _storage<T>(Future<T> operation) =>
      operation.timeout(session.vaultTimeout);

  void _sessionChanged() {
    if (_active != null && session.accountGeneration != _accountGeneration) {
      unawaited(cancel());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_sessionChanged);
    _expiration?.cancel();
    _expiration = null;
    _active = null;
    unawaited(_browser.close());
    super.dispose();
  }
}

class ZolnitRegistrationAttempt {
  const ZolnitRegistrationAttempt({
    required this.registration,
    required this.state,
    required this.verifier,
    required this.expiresAt,
  });

  final Uri registration;
  final String state;
  final String verifier;
  final DateTime expiresAt;

  bool get isValid =>
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(state) &&
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(verifier) &&
      registration.scheme == 'https' &&
      registration.host == 'link.zolmid.com' &&
      registration.port == 443 &&
      registration.userInfo.isEmpty;

  Map<String, Object> toJson() => {
    'registration': registration.toString(),
    'state': state,
    'verifier': verifier,
    'expires_at': expiresAt.millisecondsSinceEpoch,
  };

  static ZolnitRegistrationAttempt? fromJson(Map<String, dynamic> json) {
    final registration = json['registration'];
    final state = json['state'];
    final verifier = json['verifier'];
    final expiresAt = json['expires_at'];
    if (registration is! String ||
        state is! String ||
        verifier is! String ||
        expiresAt is! int) {
      return null;
    }
    final uri = Uri.tryParse(registration);
    if (uri == null) return null;
    return ZolnitRegistrationAttempt(
      registration: uri,
      state: state,
      verifier: verifier,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
    );
  }
}

class _RegistrationReturn {
  const _RegistrationReturn({required this.code, required this.state});

  final String code;
  final String state;
}

ZolnitRegistrationBrowser _registrationBrowser() =>
    Platform.isAndroid || Platform.isIOS
    ? _MobileRegistrationBrowser()
    : _DesktopRegistrationBrowser();

class _MobileRegistrationBrowser implements ZolnitRegistrationBrowser {
  bool _open = false;

  @override
  Future<void> close() async {
    if (!_open) return;
    _open = false;
    if (await supportsCloseForLaunchMode(LaunchMode.inAppBrowserView)) {
      await closeInAppWebView();
    }
  }

  @override
  Future<bool> open(
    Uri registration, {
    required ValueChanged<Uri> onReturn,
    required VoidCallback onClosed,
  }) async {
    _open = await launchUrl(registration, mode: LaunchMode.inAppBrowserView);
    return _open;
  }
}

class _DesktopRegistrationBrowser implements ZolnitRegistrationBrowser {
  Webview? _window;
  Directory? _profileDirectory;

  @override
  Future<void> close() async {
    final window = _window;
    _window = null;
    if (window != null) {
      try {
        await window.close();
      } catch (_) {}
    }
    await _deleteProfile();
  }

  @override
  Future<bool> open(
    Uri registration, {
    required ValueChanged<Uri> onReturn,
    required VoidCallback onClosed,
  }) async {
    if (!await WebviewWindow.isWebviewAvailable()) return false;
    final profile = await Directory.systemTemp.createTemp(
      'zolnit-registration-',
    );
    _profileDirectory = profile;
    try {
      final window = await WebviewWindow.create(
        configuration: CreateConfiguration(
          title: 'ZolNit',
          windowWidth: 460,
          windowHeight: 720,
          windows: WindowsWebviewOptions(
            userDataFolder: path.join(profile.path, 'WebView2'),
            denyCameraAndMicrophone: true,
          ),
        ),
      );
      _window = window;
      await window.setOnUrlRequestCallback((value) {
        final uri = Uri.tryParse(value);
        if (uri != null && isRegistrationReturnLink(uri)) {
          onReturn(uri);
          return false;
        }
        return uri != null && isZolnitRegistrationWebsiteNavigation(uri);
      });
      unawaited(
        window.onClose.then((_) async {
          if (identical(_window, window)) {
            _window = null;
            onClosed();
          }
          await _deleteProfile(profile);
        }),
      );
      await window.launch(
        registration.toString(),
        triggerOnUrlRequestEvent: false,
      );
      return true;
    } catch (_) {
      await _deleteProfile(profile);
      return false;
    }
  }

  Future<void> _deleteProfile([Directory? profile]) async {
    final target = profile ?? _profileDirectory;
    if (target == null) return;
    if (identical(target, _profileDirectory)) _profileDirectory = null;
    try {
      if (await target.exists()) await target.delete(recursive: true);
    } catch (_) {}
  }
}

bool isZolnitRegistrationWebsiteNavigation(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'link.zolmid.com' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

_RegistrationReturn? _registrationReturn(Uri uri) {
  if (!isRegistrationReturnLink(uri)) return null;
  final fragment = Uri(query: uri.fragment);
  final code = fragment.queryParameters['code'];
  final state = fragment.queryParameters['state'];
  if (fragment.queryParametersAll.length != 2 ||
      fragment.queryParametersAll['code']?.length != 1 ||
      fragment.queryParametersAll['state']?.length != 1 ||
      code == null ||
      state == null ||
      !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(code) ||
      !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(state)) {
    return null;
  }
  return _RegistrationReturn(code: code, state: state);
}

final _random = Random.secure();

List<int> _secureBytes(int length) =>
    List<int>.generate(length, (_) => _random.nextInt(256));

String _base64Url(List<int> value) =>
    base64UrlEncode(value).replaceAll('=', '');
