import 'dart:io';

import 'proxy_command.dart';

class MacosProxy {
  final ProxyCommandRunner _commandRunner;

  MacosProxy({required ProxyCommandRunner commandRunner})
    : _commandRunner = commandRunner;

  final Map<String, Map<String, _MacProxyValue>> _original = {};
  final Map<String, Map<String, _MacProxyValue>> _written = {};
  final Set<String> _restoreFailures = {};
  List<String> get restoreFailures => List.unmodifiable(_restoreFailures);
  static const _kinds = ['web', 'secureweb', 'socksfirewall', 'bypass', 'auto'];

  Future<bool> start(int port, List<String> bypassDomain) async {
    final services = await _networkServices();
    var ok = services.isNotEmpty;
    for (final service in services) {
      if (!await _startService(service, port, bypassDomain)) ok = false;
    }
    if (!ok) await stop();
    return ok;
  }

  Future<bool> _startService(
    String service,
    int port,
    List<String> bypass,
  ) async {
    final before = await _readService(service);
    if (before == null || before.values.any((v) => v.authenticated))
      return false;
    _original.putIfAbsent(service, () => before);
    var expected = Map<String, _MacProxyValue>.of(before);
    _written[service] = expected;
    for (final command in MacosProxyCommands.buildStart(
      service,
      port,
      bypass,
    )) {
      if (!await _commandRunner.run([command])) {
        final partial = await _readService(service);
        if (partial != null) _written[service] = partial;
        await _restoreService(service);
        return false;
      }
      expected = _projectWrite(expected, command);
      _written[service] = expected;
    }
    final after = await _readService(service);
    if (after == null) {
      await _restoreService(service);
      return false;
    }
    _written[service] = after;
    final valid =
        !after['auto']!.enabled &&
        after['bypass']!.bypass.join('\n') == bypass.join('\n') &&
        _kinds.take(3).every((kind) {
          final value = after[kind]!;
          return value.enabled &&
              value.server == proxyHost &&
              value.port == '$port';
        });
    if (!valid) await _restoreService(service);
    return valid;
  }

  Map<String, _MacProxyValue> _projectWrite(
    Map<String, _MacProxyValue> before,
    ProxyCommand command,
  ) {
    final result = Map<String, _MacProxyValue>.of(before);
    final args = command.args;
    final name = args.first;
    if (name == '-setautoproxystate') {
      final old = before['auto']!;
      result['auto'] = _MacProxyValue(false, old.server, '', false, const []);
    } else if (name == '-setproxybypassdomains') {
      result['bypass'] = _MacProxyValue(
        false,
        '',
        '',
        false,
        args[2] == 'Empty' ? const [] : args.sublist(2),
      );
    } else {
      for (final kind in _kinds.take(3)) {
        final old = before[kind]!;
        if (name == '-set${kind}proxy') {
          result[kind] = _MacProxyValue(
            true,
            args[2],
            args[3],
            false,
            const [],
          );
        } else if (name == '-set${kind}proxystate') {
          result[kind] = _MacProxyValue(
            args[2] == 'on',
            old.server,
            old.port,
            false,
            const [],
          );
        }
      }
    }
    return result;
  }

  Future<bool> stop() async {
    _restoreFailures.clear();
    var ok = true;
    for (final service in _original.keys.toList()) {
      if (!await _restoreService(service)) ok = false;
    }
    return ok;
  }

  Future<Map<String, _MacProxyValue>?> _readService(String service) async {
    final values = <String, _MacProxyValue>{};
    for (final kind in _kinds) {
      try {
        final result = await _commandRunner.process('/usr/sbin/networksetup', [
          kind == 'bypass'
              ? '-getproxybypassdomains'
              : kind == 'auto'
              ? '-getautoproxyurl'
              : '-get${kind}proxy',
          service,
        ]);
        if (result.exitCode != 0) return null;
        final output = result.stdout.toString();
        if (kind == 'auto' && !output.contains('Enabled:')) return null;
        if (kind != 'bypass' &&
            kind != 'auto' &&
            (!output.contains('Enabled:') ||
                !output.contains('Server:') ||
                !output.contains('Port:'))) {
          return null;
        }
        values[kind] = _MacProxyValue.parse(kind, output);
      } on ProcessException {
        return null;
      }
    }
    return values;
  }

  Future<bool> _restoreService(String service) async {
    final original = _original[service];
    final written = _written[service];
    if (original == null || written == null) {
      _restoreFailures.add(service);
      return false;
    }
    final current = await _readService(service);
    if (current == null) {
      _restoreFailures.add(service);
      return false;
    }
    var ok = true;
    for (final kind in _kinds) {
      final value = original[kind]!;
      final now = current[kind]!;
      final ours = written[kind]!;
      final List<ProxyCommand> commands;
      final _MacProxyValue expected;
      if (kind == 'bypass' || kind == 'auto') {
        if (now != ours || now == value) continue;
        commands = value.restore(service, kind);
        expected = value;
      } else {
        final endpointOwned =
            now.server == ours.server && now.port == ours.port;
        if (!endpointOwned || now.authenticated != ours.authenticated) continue;
        final restoreEndpoint =
            now.server != value.server || now.port != value.port;
        final targetEnabled = now.enabled == ours.enabled
            ? value.enabled
            : now.enabled;
        expected = _MacProxyValue(
          targetEnabled,
          value.server,
          value.port,
          value.authenticated,
          const [],
        );
        commands = [
          if (restoreEndpoint)
            ProxyCommand('/usr/sbin/networksetup', [
              '-set${kind}proxy',
              service,
              value.server,
              value.port.isEmpty ? '0' : value.port,
            ]),
          if (restoreEndpoint || now.enabled != targetEnabled)
            ProxyCommand('/usr/sbin/networksetup', [
              '-set${kind}proxystate',
              service,
              targetEnabled ? 'on' : 'off',
            ]),
        ];
      }
      var restored = true;
      for (final command in commands) {
        if (!await _commandRunner.run([command])) {
          ok = false;
          restored = false;
        }
      }
      if (commands.isNotEmpty) {
        final observed = await _readService(service);
        if (observed == null || observed[kind] != expected) {
          ok = false;
          restored = false;
        }
        if (!restored) _restoreFailures.add('$service / $kind');
        if (!restored && observed != null) written[kind] = observed[kind]!;
      }
    }
    if (ok) {
      _original.remove(service);
      _written.remove(service);
    }
    return ok;
  }

  Future<List<String>> _networkServices() async {
    try {
      final result = await _commandRunner.process('/usr/sbin/networksetup', [
        '-listallnetworkservices',
      ]);
      if (result.exitCode != 0) {
        return [];
      }
      return MacosProxyCommands.parseNetworkServices(result.stdout.toString());
    } on ProcessException {
      return [];
    }
  }
}

class MacosProxyCommands {
  static List<ProxyCommand> buildStart(
    String service,
    int port,
    List<String> bypassDomain,
  ) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setautoproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxy',
        service,
        proxyHost,
        '$port',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxy',
        service,
        proxyHost,
        '$port',
      ]),
      buildProxyBypass(service, bypassDomain),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'on',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'on',
      ]),
    ];
  }

  static List<ProxyCommand> buildStop(String service) {
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-setautoproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setwebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsecurewebproxystate',
        service,
        'off',
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-setsocksfirewallproxystate',
        service,
        'off',
      ]),
      buildProxyBypass(service, const []),
    ];
  }

  static ProxyCommand buildProxyBypass(
    String service,
    List<String> bypassDomain,
  ) {
    return ProxyCommand('/usr/sbin/networksetup', [
      '-setproxybypassdomains',
      service,
      if (bypassDomain.isEmpty) 'Empty' else ...bypassDomain,
    ]);
  }

  static List<String> parseNetworkServices(String stdout) {
    return stdout
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !line.startsWith('*'))
        .where((line) => !line.startsWith('An asterisk '))
        .toList();
  }
}

class _MacProxyValue {
  final bool enabled;
  final String server;
  final String port;
  final bool authenticated;
  final List<String> bypass;

  const _MacProxyValue(
    this.enabled,
    this.server,
    this.port,
    this.authenticated,
    this.bypass,
  );

  factory _MacProxyValue.parse(String kind, String output) {
    if (kind == 'bypass') {
      final lines = output
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return _MacProxyValue(
        false,
        '',
        '',
        false,
        lines.any((s) => s.startsWith('There aren')) ? [] : lines,
      );
    }
    final fields = <String, String>{};
    for (final line in output.split('\n')) {
      final index = line.indexOf(':');
      if (index >= 0)
        fields[line.substring(0, index).trim()] = line
            .substring(index + 1)
            .trim();
    }
    if (kind == 'auto') {
      return _MacProxyValue(
        fields['Enabled'] == 'Yes',
        fields['URL'] ?? '',
        '',
        false,
        const [],
      );
    }
    return _MacProxyValue(
      fields['Enabled'] == 'Yes',
      fields['Server'] ?? '',
      fields['Port'] ?? '',
      fields['Authenticated Proxy Enabled'] == '1' ||
          fields['Authenticated Proxy Enabled'] == 'Yes',
      const [],
    );
  }

  List<ProxyCommand> restore(String service, String kind) {
    if (kind == 'bypass')
      return [MacosProxyCommands.buildProxyBypass(service, bypass)];
    if (kind == 'auto') {
      return [
        ProxyCommand('/usr/sbin/networksetup', [
          '-setautoproxystate',
          service,
          enabled ? 'on' : 'off',
        ]),
      ];
    }
    return [
      ProxyCommand('/usr/sbin/networksetup', [
        '-set${kind}proxy',
        service,
        server,
        port.isEmpty ? '0' : port,
      ]),
      ProxyCommand('/usr/sbin/networksetup', [
        '-set${kind}proxystate',
        service,
        enabled ? 'on' : 'off',
      ]),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is _MacProxyValue &&
      enabled == other.enabled &&
      server == other.server &&
      port == other.port &&
      authenticated == other.authenticated &&
      bypass.join('\n') == other.bypass.join('\n');
  @override
  int get hashCode =>
      Object.hash(enabled, server, port, authenticated, Object.hashAll(bypass));
}
