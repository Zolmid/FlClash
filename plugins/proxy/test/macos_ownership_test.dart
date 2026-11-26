import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy/src/macos_proxy.dart';
import 'package:proxy/src/proxy_command.dart';

class FakeNetwork {
  final Map<String, Map<String, List<String>>> state = {
    for (final s in ['Wi-Fi', 'Ethernet'])
      s: {
        for (final k in ['web', 'secureweb', 'socksfirewall'])
          k: ['No', 'old.$s', '8080'],
        'bypass': ['local'],
        'auto': ['Yes', 'https://example.invalid/proxy.pac'],
      },
  };
  String? failure;
  bool failNextReadAfterWrite = false;
  bool _failedReadPending = false;
  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    bool runInShell = false,
  }) async {
    final command = args[0];
    if (command == '-listallnetworkservices')
      return ProcessResult(0, 0, 'Wi-Fi\nEthernet\n', '');
    final service = args[1];
    if (_failedReadPending && command.startsWith('-get')) {
      _failedReadPending = false;
      return ProcessResult(0, 1, '', 'read failed');
    }
    if (failure == '$service:$command') {
      failure = null;
      return ProcessResult(0, 1, '', 'failed');
    }
    final values = state[service]!;
    if (command == '-getautoproxyurl') {
      return ProcessResult(
        0,
        0,
        'Enabled: ${values['auto']![0]}\nURL: ${values['auto']![1]}\n',
        '',
      );
    }
    if (command == '-setautoproxystate') {
      values['auto']![0] = args[2] == 'on' ? 'Yes' : 'No';
      return ProcessResult(0, 0, '', '');
    }
    if (command == '-getproxybypassdomains')
      return ProcessResult(0, 0, values['bypass']!.join('\n'), '');
    if (command == '-setproxybypassdomains') {
      values['bypass'] = args.skip(2).toList();
      return ProcessResult(0, 0, '', '');
    }
    for (final kind in ['web', 'secureweb', 'socksfirewall']) {
      final v = values[kind]!;
      if (command == '-get${kind}proxy')
        return ProcessResult(
          0,
          0,
          'Enabled: ${v[0]}\nServer: ${v[1]}\nPort: ${v[2]}\n',
          '',
        );
      if (command == '-set${kind}proxy') {
        v[0] = 'Yes';
        v[1] = args[2];
        v[2] = args[3];
        if (failNextReadAfterWrite) {
          failNextReadAfterWrite = false;
          _failedReadPending = true;
        }
        return ProcessResult(0, 0, '', '');
      }
      if (command == '-set${kind}proxystate') {
        v[0] = args[2] == 'on' ? 'Yes' : 'No';
        return ProcessResult(0, 0, '', '');
      }
    }
    throw StateError('$args');
  }
}

void main() {
  test('a failed readback retains enough ownership to roll back', () async {
    final fake = FakeNetwork()..failNextReadAfterWrite = true;
    final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
    expect(await proxy.start(7890, ['localhost']), isFalse);
    expect(fake.state['Wi-Fi']!['web'], ['No', 'old.Wi-Fi', '8080']);
    expect(fake.state['Wi-Fi']!['auto']![0], 'Yes');
  });
  test(
    'partial failure restores one service and still processes the other',
    () async {
      final fake = FakeNetwork()..failure = 'Wi-Fi:-setsecurewebproxy';
      final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
      expect(await proxy.start(7890, ['localhost']), isFalse);
      expect(fake.state['Wi-Fi']!['web'], ['No', 'old.Wi-Fi', '8080']);
      expect(fake.state['Ethernet']!['web'], ['No', 'old.Ethernet', '8080']);
      expect(await proxy.stop(), isTrue);
      expect(fake.state['Ethernet']!['web'], ['No', 'old.Ethernet', '8080']);
      expect(fake.state['Ethernet']!['auto'], [
        'Yes',
        'https://example.invalid/proxy.pac',
      ]);
    },
  );
  test('stop without ownership does not touch existing settings', () async {
    final fake = FakeNetwork();
    final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
    expect(await proxy.stop(), isTrue);
    expect(fake.state['Wi-Fi']!['web'], ['No', 'old.Wi-Fi', '8080']);
  });
  test('preserves a PAC URL the user changes during takeover', () async {
    final fake = FakeNetwork();
    final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
    expect(await proxy.start(7890, ['localhost']), isTrue);
    fake.state['Wi-Fi']!['auto'] = ['Yes', 'https://example.invalid/new.pac'];
    expect(await proxy.stop(), isTrue);
    expect(fake.state['Wi-Fi']!['auto'], [
      'Yes',
      'https://example.invalid/new.pac',
    ]);
  });
  test('preserves user changes made after takeover', () async {
    final fake = FakeNetwork();
    final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
    expect(await proxy.start(7890, ['localhost']), isTrue);
    fake.state['Wi-Fi']!['web'] = ['Yes', 'user.proxy', '8888'];
    expect(await proxy.stop(), isTrue);
    expect(fake.state['Wi-Fi']!['web'], ['Yes', 'user.proxy', '8888']);
    expect(fake.state['Wi-Fi']!['secureweb'], ['No', 'old.Wi-Fi', '8080']);
  });
  test(
    'preserves a user state change while restoring the owned endpoint',
    () async {
      final fake = FakeNetwork();
      final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
      expect(await proxy.start(7890, ['localhost']), isTrue);
      fake.state['Wi-Fi']!['web']![0] = 'No';
      expect(await proxy.stop(), isTrue);
      expect(fake.state['Wi-Fi']!['web'], ['No', 'old.Wi-Fi', '8080']);
    },
  );
  test(
    'a failed restore does not skip the other service and can retry',
    () async {
      final fake = FakeNetwork();
      final proxy = MacosProxy(commandRunner: ProxyCommandRunner(fake.run));
      expect(await proxy.start(7890, ['localhost']), isTrue);
      fake.failure = 'Wi-Fi:-setwebproxy';
      expect(await proxy.stop(), isFalse);
      expect(fake.state['Ethernet']!['web'], ['No', 'old.Ethernet', '8080']);
      expect(await proxy.stop(), isTrue);
      expect(fake.state['Wi-Fi']!['web'], ['No', 'old.Wi-Fi', '8080']);
    },
  );
}
