import 'dart:convert';

const nativeUiChannelName = 'com.zolmid.zolnit/native-ui';
const nativeUiViewType = 'com.zolmid.zolnit/native-home';
const nativeUiSchemaVersion = 1;

const nativeUiRequiredLabels = <String>{
  'connect',
  'disconnect',
  'disconnected',
  'connecting',
  'connected',
  'disconnecting',
  'connectionFailed',
  'smartMode',
  'globalMode',
  'servers',
  'plans',
  'account',
  'refresh',
  'preferences',
  'help',
  'trafficRemaining',
  'trafficUsed',
  'upload',
  'download',
  'noPlan',
  'noServers',
  'signIn',
  'restoringSession',
  'offline',
  'retry',
  'safeMode',
  'selectServer',
  'currentPlan',
  'loading',
};

const _destinations = {'connect', 'servers', 'plans', 'account'};
const _returnRouteIds = {'direct', 'hk_lite', 'hk_optimized'};
const _modes = {'rule', 'global'};
const _actions = {
  'connect',
  'disconnect',
  'selectServer',
  'selectReturnRoute',
  'setMode',
  'navigate',
  'refresh',
  'preferences',
  'help',
};
const _receiptErrors = {
  'stale_account',
  'unauthenticated',
  'invalid_command',
  'unavailable',
  'safe_mode',
  'failed',
};

Never _invalid(String field) =>
    throw FormatException('Invalid native UI field: $field');

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map<String, dynamic>) _invalid(field);
  return value;
}

void _keys(Map<String, dynamic> value, Set<String> allowed, String field) {
  if (value.keys.any((key) => !allowed.contains(key))) _invalid(field);
}

int _integer(Object? value, String field) {
  if (value is! int || value < 0) _invalid(field);
  return value;
}

String _string(Object? value, String field, {int maxLength = 4096}) {
  if (value is! String || value.isEmpty || value.length > maxLength) {
    _invalid(field);
  }
  return value;
}

void _choice(Object? value, Set<String> choices, String field) {
  if (value is! String || !choices.contains(value)) _invalid(field);
}

void _version(Map<String, dynamic> value) {
  if (value['schemaVersion'] is! int ||
      value['schemaVersion'] != nativeUiSchemaVersion) {
    _invalid('schemaVersion');
  }
}

Map<String, dynamic> _decode(String source, {int maxLength = 2097152}) {
  if (source.length > maxLength) _invalid('payload');
  try {
    return _object(jsonDecode(source), 'payload');
  } on FormatException {
    _invalid('payload');
  }
}

class NativeUiReturnRoute {
  NativeUiReturnRoute._(
    this.title,
    this.selectedId,
    this.enabled,
    this.options,
  );

  static NativeUiReturnRoute? parse(Object? raw) {
    if (raw == null) return null;
    try {
      final value = _object(raw, 'returnRoute');
      _keys(value, {
        'title',
        'selectedId',
        'enabled',
        'options',
      }, 'returnRoute');
      final title = _string(value['title'], 'returnRoute.title');
      if (value['enabled'] is! bool) _invalid('returnRoute.enabled');
      final options = value['options'];
      if (options is! List || options.length > 3) {
        _invalid('returnRoute.options');
      }
      final labels = <String, String>{};
      for (final rawOption in options) {
        final option = _object(rawOption, 'returnRoute.option');
        _keys(option, {'id', 'label'}, 'returnRoute.option');
        _choice(option['id'], _returnRouteIds, 'returnRoute.option.id');
        final id = option['id'] as String;
        if (labels.containsKey(id)) _invalid('returnRoute.option.id');
        labels[id] = _string(option['label'], 'returnRoute.option.label');
      }
      final selected = value['selectedId'];
      if (selected != null &&
          (selected is! String || !labels.containsKey(selected))) {
        _invalid('returnRoute.selectedId');
      }
      return NativeUiReturnRoute._(
        title,
        selected as String?,
        value['enabled'] as bool,
        Map.unmodifiable(labels),
      );
    } on FormatException {
      return null;
    }
  }

  final String title;
  final String? selectedId;
  final bool enabled;
  final Map<String, String> options;

  Map<String, dynamic> toJson() => {
    'title': title,
    'selectedId': selectedId,
    'enabled': enabled,
    'options': [
      for (final entry in options.entries)
        {'id': entry.key, 'label': entry.value},
    ],
  };
}

class NativeUiSnapshot {
  NativeUiSnapshot._(
    this._encoded,
    this.revision,
    this.accountGeneration,
    this.sessionStatus,
    this.safeMode,
    this.returnRoute,
    Set<String> availableServers,
  ) : _availableServers = Set.unmodifiable(availableServers);

  factory NativeUiSnapshot.decode(String source) =>
      NativeUiSnapshot.fromJson(_decode(source));

  factory NativeUiSnapshot.fromJson(Map<String, dynamic> value) {
    _keys(value, {
      'schemaVersion',
      'revision',
      'accountGeneration',
      'locale',
      'textDirection',
      'safeMode',
      'sessionStatus',
      'connectionState',
      'destination',
      'mode',
      'selectedServerId',
      'servers',
      'planName',
      'planExpiresAt',
      'usage',
      'traffic',
      'labels',
      'returnRoute',
    }, 'snapshot');
    _version(value);
    final revision = _integer(value['revision'], 'revision');
    final generation = _integer(
      value['accountGeneration'],
      'accountGeneration',
    );
    _string(value['locale'], 'locale', maxLength: 64);
    _choice(value['textDirection'], {'ltr', 'rtl'}, 'textDirection');
    if (value['safeMode'] is! bool) _invalid('safeMode');
    _choice(value['sessionStatus'], {
      'restoring',
      'signedOut',
      'signedIn',
      'offline',
      'expired',
    }, 'sessionStatus');
    _choice(value['connectionState'], {
      'disconnected',
      'connecting',
      'connected',
      'disconnecting',
      'failed',
    }, 'connectionState');
    _choice(value['destination'], _destinations, 'destination');
    _choice(value['mode'], _modes, 'mode');
    final servers = value['servers'];
    if (servers is! List || servers.length > 10000) _invalid('servers');
    final serverIds = <String>{};
    final availableServers = <String>{};
    for (final raw in servers) {
      final server = _object(raw, 'server');
      _keys(server, {'id', 'name', 'available', 'latencyMs'}, 'server');
      final id = _string(server['id'], 'server.id', maxLength: 512);
      if (!serverIds.add(id)) _invalid('server.id');
      _string(server['name'], 'server.name', maxLength: 512);
      if (server['available'] is! bool) _invalid('server.available');
      if (server['available'] == true) availableServers.add(id);
      if (server['latencyMs'] != null) {
        _integer(server['latencyMs'], 'server.latencyMs');
      }
    }
    final selected = value['selectedServerId'];
    if (selected != null &&
        (selected is! String || !serverIds.contains(selected))) {
      _invalid('selectedServerId');
    }
    if (value['planName'] != null) _string(value['planName'], 'planName');
    if (value['planExpiresAt'] != null) {
      _integer(value['planExpiresAt'], 'planExpiresAt');
    }
    final usage = _object(value['usage'], 'usage');
    _keys(usage, {'usedBytes', 'totalBytes'}, 'usage');
    if (usage['usedBytes'] != null) {
      _integer(usage['usedBytes'], 'usage.usedBytes');
    }
    if (usage['totalBytes'] != null) {
      _integer(usage['totalBytes'], 'usage.totalBytes');
    }
    final traffic = _object(value['traffic'], 'traffic');
    _keys(traffic, {'uploadBps', 'downloadBps'}, 'traffic');
    for (final key in ['uploadBps', 'downloadBps']) {
      if (traffic[key] != null) _integer(traffic[key], 'traffic.$key');
    }
    final labels = _object(value['labels'], 'labels');
    _keys(labels, nativeUiRequiredLabels, 'labels');
    for (final key in nativeUiRequiredLabels) {
      _string(labels[key], 'labels.$key');
    }
    final returnRoute = NativeUiReturnRoute.parse(value['returnRoute']);
    final normalized = Map<String, dynamic>.of(value);
    if (value.containsKey('returnRoute')) {
      normalized['returnRoute'] = returnRoute?.toJson();
    }
    final encoded = jsonEncode(normalized);
    if (encoded.length > 2097152) _invalid('payload');
    return NativeUiSnapshot._(
      encoded,
      revision,
      generation,
      value['sessionStatus'] as String,
      value['safeMode'] as bool,
      returnRoute,
      availableServers,
    );
  }

  final String _encoded;
  final int revision;
  final int accountGeneration;
  final String sessionStatus;
  final bool safeMode;
  final NativeUiReturnRoute? returnRoute;
  final Set<String> _availableServers;

  String encode() => _encoded;
  Map<String, dynamic> toJson() => _decode(_encoded);
  bool containsAvailableServer(String id) => _availableServers.contains(id);
}

class NativeUiCommand {
  NativeUiCommand._(
    this.id,
    this.accountGeneration,
    this.action,
    this._encoded,
  );

  factory NativeUiCommand.decode(String source) {
    final value = _decode(source, maxLength: 65536);
    _keys(value, {
      'schemaVersion',
      'id',
      'accountGeneration',
      'action',
      'payload',
    }, 'command');
    _version(value);
    final id = _string(value['id'], 'id', maxLength: 128);
    final generation = _integer(
      value['accountGeneration'],
      'accountGeneration',
    );
    _choice(value['action'], _actions, 'action');
    final action = value['action'] as String;
    final payload = _object(value['payload'], 'payload');
    switch (action) {
      case 'selectServer':
        _keys(payload, {'serverId'}, 'payload');
        _string(payload['serverId'], 'serverId', maxLength: 512);
      case 'selectReturnRoute':
        _keys(payload, {'optionId'}, 'payload');
        _choice(payload['optionId'], _returnRouteIds, 'optionId');
      case 'setMode':
        _keys(payload, {'mode'}, 'payload');
        _choice(payload['mode'], _modes, 'mode');
      case 'navigate':
        _keys(payload, {'destination'}, 'payload');
        _choice(payload['destination'], _destinations, 'destination');
      default:
        _keys(payload, {}, 'payload');
    }
    return NativeUiCommand._(id, generation, action, jsonEncode(value));
  }

  final String id;
  final int accountGeneration;
  final String action;
  final String _encoded;

  String encode() => _encoded;
  Map<String, dynamic> get payload =>
      _object(_decode(_encoded)['payload'], 'payload');
}

class NativeUiReceipt {
  const NativeUiReceipt.accepted(this.id) : accepted = true, errorCode = null;

  factory NativeUiReceipt.rejected(String id, String errorCode) {
    _choice(errorCode, _receiptErrors, 'errorCode');
    return NativeUiReceipt._(id, false, errorCode);
  }

  const NativeUiReceipt._(this.id, this.accepted, this.errorCode);

  final String id;
  final bool accepted;
  final String? errorCode;

  String encode() => jsonEncode({
    'schemaVersion': nativeUiSchemaVersion,
    'id': id,
    'accepted': accepted,
    'errorCode': errorCode,
  });
}
