import 'package:fl_clash/common/managed_dns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = <String, dynamic>{
    'nameserver': ['https://dns.example/dns-query'],
    'nameserver-policy': {
      '+.protected.example': ['https://dns.example/dns-query'],
    },
  };
  test(
    'inherits private and local policies but keeps public source resolvers',
    () {
      final dns = managedDnsMerge(source, {
        'nameserver': ['system://'],
        'nameserver-policy': {
          '+.corp.example': ['10.0.0.1', 'fd00::1'],
          '+.lan': ['system'],
          '+.public.example': ['8.8.8.8'],
          '+.protected.example': ['10.0.0.2'],
        },
      });
      expect(dns['enable'], true);
      expect(dns['nameserver'], source['nameserver']);
      expect(dns['nameserver-policy']['+.corp.example'], [
        '10.0.0.1',
        'fd00::1',
      ]);
      expect(dns['nameserver-policy']['+.lan'], ['system']);
      expect(dns['nameserver-policy'], isNot(contains('+.public.example')));
      expect(dns['nameserver-policy']['+.protected.example'], [
        'https://dns.example/dns-query',
      ]);
    },
  );
  test('refuses overlapping and opaque signed policies', () {
    for (final policy in [
      {'+.example': 'https://dns.example/dns-query'},
      {'rule-set:public': 'https://dns.example/dns-query'},
      {'geosite:cn': 'https://dns.example/dns-query'},
    ]) {
      expect(
        () => managedDnsMerge(
          {
            'nameserver': ['https://dns.example/dns-query'],
            'nameserver-policy': policy,
          },
          {
            'nameserver-policy': {
              '+.corp.example': ['10.0.0.1'],
            },
          },
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'requires encrypted public resolvers in all fields and both policies',
    () {
      for (final key in [
        'nameserver',
        'fallback',
        'default-nameserver',
        'direct-nameserver',
        'proxy-server-nameserver',
      ]) {
        for (final value in [
          '223.5.5.5',
          'udp://223.5.5.5',
          'tcp://8.8.8.8:53',
        ]) {
          expect(
            () => managedDnsMerge({
              'nameserver': ['https://dns.example/dns-query'],
              key: [value],
            }, {}),
            throwsFormatException,
          );
        }
      }
      for (final key in [
        'nameserver-policy',
        'proxy-server-nameserver-policy',
      ]) {
        for (final domain in [
          'rule-set:public',
          'geosite:cn',
          '+.public.example',
        ]) {
          expect(
            () => managedDnsMerge({
              'nameserver': ['tls://dns.example'],
              key: {
                domain: ['udp://223.5.5.5'],
              },
            }, {}),
            throwsFormatException,
          );
        }
        expect(
          managedDnsMerge({
            'nameserver': ['tls://dns.example'],
            key: {
              '+.corp.example': ['10.0.0.53:53'],
              'rule-set:public': ['https://dns.example/dns-query'],
            },
          }, {}),
          isNotEmpty,
        );
      }
    },
  );

  test('rejects missing, disabled, empty and system-wide DNS', () {
    for (final dns in <Map<String, dynamic>>[
      {},
      {
        'enable': false,
        'nameserver': ['https://dns.example/dns-query'],
      },
      {'nameserver': <String>[]},
      {
        'nameserver': ['system://'],
      },
    ]) {
      expect(() => managedDnsMerge(dns, {}), throwsFormatException);
    }
  });
}
