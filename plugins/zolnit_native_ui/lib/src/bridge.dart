import 'dart:async';

import 'package:flutter/services.dart';

import 'protocol.dart';

typedef NativeUiCommandHandler =
    Future<NativeUiReceipt> Function(NativeUiCommand command);

class _CommandFlight {
  _CommandFlight(this.id, this.fingerprint);

  final String id;
  final String fingerprint;
  final result = Completer<NativeUiReceipt>();
  bool complete = false;
}

class NativeUiBridge {
  NativeUiBridge({
    required NativeUiCommandHandler onCommand,
    MethodChannel channel = const MethodChannel(nativeUiChannelName),
  }) : _onCommand = onCommand,
       _channel = channel {
    final previous = _owners[channel.name];
    _owners[channel.name] = this;
    previous?._cancelCommands();
    _channel.setMethodCallHandler(_receive);
  }

  static final _owners = <String, NativeUiBridge>{};
  final NativeUiCommandHandler _onCommand;
  final MethodChannel _channel;
  final _commands = <String, _CommandFlight>{};
  NativeUiSnapshot? _snapshot;
  bool _disposed = false;

  bool get _active => !_disposed && identical(_owners[_channel.name], this);

  NativeUiSnapshot? get snapshot => _snapshot;

  Future<bool> isAvailable() async {
    if (!_active) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> publishSnapshot(NativeUiSnapshot snapshot) async {
    if (!_active) return false;
    final previous = _snapshot;
    if (previous != null &&
        (snapshot.revision <= previous.revision ||
            snapshot.accountGeneration < previous.accountGeneration)) {
      return false;
    }
    if (previous?.accountGeneration != snapshot.accountGeneration) {
      _cancelCommands();
    }
    _snapshot = snapshot;
    try {
      await _channel.invokeMethod<void>('publishSnapshot', snapshot.encode());
      return _active;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<Object?> _receive(MethodCall call) async {
    if (!_active) return null;
    switch (call.method) {
      case 'getSnapshot':
        return _snapshot?.encode();
      case 'performCommand':
        final arguments = call.arguments;
        if (arguments is! String) {
          return NativeUiReceipt.rejected('', 'invalid_command').encode();
        }
        NativeUiCommand command;
        try {
          command = NativeUiCommand.decode(arguments);
        } on FormatException {
          return NativeUiReceipt.rejected('', 'invalid_command').encode();
        }
        return (await _perform(command)).encode();
      default:
        throw MissingPluginException('Unsupported native UI method');
    }
  }

  Future<NativeUiReceipt> _perform(NativeUiCommand command) async {
    final current = _snapshot;
    if (current == null) {
      return NativeUiReceipt.rejected(command.id, 'unavailable');
    }
    if (command.accountGeneration != current.accountGeneration) {
      return NativeUiReceipt.rejected(command.id, 'stale_account');
    }
    final changesNetwork = {
      'connect',
      'disconnect',
      'selectServer',
      'selectReturnRoute',
      'setMode',
    }.contains(command.action);
    if (current.safeMode && changesNetwork) {
      return NativeUiReceipt.rejected(command.id, 'safe_mode');
    }
    final requiresAccount = {
      'connect',
      'selectServer',
      'selectReturnRoute',
      'setMode',
    }.contains(command.action);
    if (requiresAccount && current.sessionStatus != 'signedIn') {
      final unauthenticated = {
        'signedOut',
        'expired',
      }.contains(current.sessionStatus);
      return NativeUiReceipt.rejected(
        command.id,
        unauthenticated ? 'unauthenticated' : 'unavailable',
      );
    }
    if (command.action == 'selectServer' &&
        !current.containsAvailableServer(
          command.payload['serverId'] as String,
        )) {
      return NativeUiReceipt.rejected(command.id, 'invalid_command');
    }
    final previous = _commands[command.id];
    if (previous != null) {
      if (previous.fingerprint != command.encode()) {
        return NativeUiReceipt.rejected(command.id, 'invalid_command');
      }
      return previous.result.future;
    }
    if (command.action == 'selectReturnRoute') {
      final route = current.returnRoute;
      if (route == null ||
          !route.options.containsKey(command.payload['optionId'])) {
        return NativeUiReceipt.rejected(command.id, 'invalid_command');
      }
      if (!route.enabled ||
          _commands.values.any((flight) => !flight.complete)) {
        return NativeUiReceipt.rejected(command.id, 'unavailable');
      }
    }
    while (_commands.length >= 128) {
      final completed = _commands.entries
          .where((entry) => entry.value.complete)
          .firstOrNull;
      if (completed == null) {
        return NativeUiReceipt.rejected(command.id, 'unavailable');
      }
      _commands.remove(completed.key);
    }
    final flight = _CommandFlight(command.id, command.encode());
    _commands[command.id] = flight;
    unawaited(_execute(command, flight));
    return flight.result.future;
  }

  Future<void> _execute(NativeUiCommand command, _CommandFlight flight) async {
    NativeUiReceipt result;
    try {
      result = await _onCommand(command);
      if (result.id != command.id) {
        result = NativeUiReceipt.rejected(command.id, 'failed');
      }
    } catch (_) {
      result = NativeUiReceipt.rejected(command.id, 'failed');
    }
    if (!_active || _snapshot?.accountGeneration != command.accountGeneration) {
      result = NativeUiReceipt.rejected(command.id, 'stale_account');
    }
    flight.complete = true;
    if (!flight.result.isCompleted) flight.result.complete(result);
  }

  void _cancelCommands() {
    for (final flight in _commands.values) {
      if (!flight.result.isCompleted) {
        flight.result.complete(
          NativeUiReceipt.rejected(flight.id, 'stale_account'),
        );
      }
    }
    _commands.clear();
  }

  Future<void> setSurfaceBounds(Rect rect, double devicePixelRatio) async {
    if (!_active ||
        !rect.isFinite ||
        rect.width < 0 ||
        rect.height < 0 ||
        !devicePixelRatio.isFinite ||
        devicePixelRatio <= 0) {
      return;
    }
    await _hostMethod('setSurfaceBounds', {
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
      'devicePixelRatio': devicePixelRatio,
    });
  }

  Future<void> showSurface() => _hostMethod('showSurface');
  Future<void> hideSurface() => _hostMethod('hideSurface');

  Future<void> _hostMethod(String method, [Object? arguments]) async {
    if (!_active) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelCommands();
    if (identical(_owners[_channel.name], this)) {
      _owners.remove(_channel.name);
      _channel.setMethodCallHandler(null);
    }
  }
}
