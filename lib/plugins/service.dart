import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final _utf8JsonDecoder = utf8.decoder.fuse(json.decoder);

Object? _decodeUtf8Json(Uint8List data) => _utf8JsonDecoder.convert(data);

Map<String, Object?> _decodeResponseOf((Object, CoreMethod) request) {
  final (data, method) = request;
  final decoded = data is String
      ? json.decode(data)
      : _decodeUtf8Json(data as Uint8List);
  return withResultModel(method, Map<String, Object?>.from(decoded as Map));
}

Future<Map<String, Object?>> _decodeResponse(
  Object data,
  CoreMethod method,
) async {
  final length = data is String ? data.length : (data as Uint8List).length;
  if (length < 51200) {
    return _decodeResponseOf((data, method));
  }
  return compute(_decodeResponseOf, (data, method));
}

abstract mixin class ServiceListener {
  void onServiceEvent(CoreEvent event) {}

  void onServiceStopped() {}
}

enum TunnelState { pending, connected, disconnected }

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  final bool _isIOS;
  final _tunnelState = ValueNotifier(TunnelState.pending);
  static const _coreChannel = MethodChannel('$packageName/core');

  ValueListenable<TunnelState> get tunnelState => _tunnelState;

  final ObserverList<ServiceListener> _listeners =
      ObserverList<ServiceListener>();

  int _commandRevision = 0;
  bool _startRequested = false;
  bool _disposed = false;

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    methodChannel.setMethodCallHandler(null);
    for (final listener in List.of(_listeners)) {
      _listeners.remove(listener);
    }
    _tunnelState.dispose();
  }

  Service._internal() : this._(isIOS: system.isIOS);

  @visibleForTesting
  Service.forTesting({required bool isIOS}) : this._(isIOS: isIOS);

  Service._({required bool isIOS}) : _isIOS = isIOS {
    methodChannel = const MethodChannel('$packageName/service');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'tunnelState':
          _tunnelState.value = TunnelState.values.byName(
            call.arguments as String,
          );
          break;
        case 'event':
          final data = call.arguments;
          final decoded = data is String
              ? json.decode(data)
              : _decodeUtf8Json(data as Uint8List);
          final methodCall = CoreMethodCall.fromJson(
            Map<String, Object?>.from(decoded as Map),
          );
          for (final event in coreEventsFromData(methodCall.arguments)) {
            _dispatch(
              'Core event ${event.type.name}',
              (listener) => listener.onServiceEvent(event),
            );
          }
          break;
        case 'stopped':
          // A report stamped before the newest command no longer describes it.
          if (call.arguments != _commandRevision || !_startRequested) {
            break;
          }
          _startRequested = false;
          _dispatch('stop report', (listener) => listener.onServiceStopped());
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<CoreMethodResponse?> invokeMethod(CoreMethodCall call) async {
    final channel = _isIOS ? methodChannel : _coreChannel;
    final data = await channel.invokeMethod<Object>(
      'invokeMethod',
      json.encode(call),
    );
    if (data == null) {
      return null;
    }
    return resolveSpilledResponse(
      CoreMethodResponse.fromJson(await _decodeResponse(data, call.method)),
      method: call.method,
    );
  }

  void _dispatch(String label, void Function(ServiceListener) deliver) {
    for (final listener in List.of(_listeners)) {
      try {
        deliver(listener);
      } catch (error) {
        commonPrint.log(
          'Unable to dispatch $label: $error',
          logLevel: LogLevel.error,
        );
      }
    }
  }

  Future<bool> start([SharedState? state]) async {
    _startRequested = true;
    final revision = ++_commandRevision;
    if (_isIOS && state == null) {
      throw ArgumentError.notNull('state');
    }
    return await methodChannel.invokeMethod<bool>(
          'start',
          _isIOS ? json.encode(state) : revision,
        ) ??
        false;
  }

  Future<bool> stop() async {
    _startRequested = false;
    final revision = ++_commandRevision;
    return await methodChannel.invokeMethod<bool>(
          'stop',
          _isIOS ? null : revision,
        ) ??
        false;
  }

  Future<String> init() async {
    return await methodChannel.invokeMethod<String>(
          'init',
          _isIOS ? safeModeBuild : null,
        ) ??
        '';
  }

  Future<String> syncState(SharedState state) async {
    return await methodChannel.invokeMethod<String>(
          'syncState',
          json.encode(state),
        ) ??
        '';
  }

  Future<bool> shutdown() async {
    return await methodChannel.invokeMethod<bool>('shutdown') ?? true;
  }

  Future<DateTime?> getRunTime() async {
    final ms = await methodChannel.invokeMethod<int>('getRunTime') ?? 0;
    if (ms == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<VpnOptions?> getActiveVpnOptions() async {
    return _getVpnOptions('getActiveVpnOptions');
  }

  Future<VpnOptions?> getRequestedVpnOptions() async {
    return _getVpnOptions('getRequestedVpnOptions');
  }

  Future<VpnOptions?> _getVpnOptions(String method) async {
    final data = await methodChannel.invokeMethod<String>(method);
    if (data == null) {
      return null;
    }
    return VpnOptions.fromJson(
      Map<String, Object?>.from(json.decode(data) as Map),
    );
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ServiceListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ServiceListener listener) {
    _listeners.remove(listener);
  }
}

Service? get service => system.isMobile ? Service() : null;
