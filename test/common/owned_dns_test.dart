import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/owned_dns.dart';

void main() {
  test(
    'production socket bootstrap allows late family to beat blackhole',
    () async {
      for (final first in [1, 28]) {
        for (final blackhole in [false, true]) {
          final later = Completer<OwnedDnsAnswer>();
          final stalled = Completer<Socket>();
          var cancelled = false;
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) {
            request.response.write('ok');
            unawaited(request.response.close());
          });
          final attempts = <InternetAddress>[];
          final resolver = OwnedDnsResolver(
            hosts: {'link.zolmid.com'},
            lookup: (_) async =>
                throw StateError('pure resolver should not run'),
            transportLookup: (_) => bootstrapZolnitOrigin(
              firstUsable: true,
              query: (type) async => type == first
                  ? OwnedDnsAnswer([
                      type == 1 ? '192.0.2.1' : '2001:db8::1',
                    ], 30)
                  : later.future,
            ),
          );
          final client = resolver.createHttpClient(
            startConnect: (address, port) async {
              attempts.add(address);
              if (attempts.length == 1) {
                Timer(
                  const Duration(milliseconds: 50),
                  () => later.complete(
                    OwnedDnsAnswer([
                      first == 1 ? '2001:db8::1' : '192.0.2.1',
                    ], 30),
                  ),
                );
                if (blackhole) {
                  return ConnectionTask.fromSocket(stalled.future, () {
                    cancelled = true;
                    if (!stalled.isCompleted) {
                      stalled.completeError(const SocketException('cancelled'));
                    }
                  });
                }
                throw const SocketException('first family sockets failed');
              }
              return Socket.startConnect(InternetAddress.loopbackIPv4, port);
            },
          );
          addTearDown(() => client.close(force: true));
          final watch = Stopwatch()..start();
          final response = await (await client.getUrl(
            Uri.parse('http://link.zolmid.com:${server.port}/'),
          )).close();
          await response.drain<void>();
          expect(watch.elapsedMilliseconds, inInclusiveRange(40, 1500));
          expect(attempts.length, 2);
          expect(attempts.first.type, isNot(attempts.last.type));
          if (blackhole) expect(cancelled, isTrue);
        }
      }
    },
  );

  test(
    'first usable bootstrap returns before a late family; pure API waits',
    () async {
      final late = Completer<OwnedDnsAnswer>();
      final early = await bootstrapZolnitOrigin(
        firstUsable: true,
        query: (type) async =>
            type == 28 ? OwnedDnsAnswer(['2001:db8::1'], 30) : late.future,
      ).timeout(const Duration(milliseconds: 500));
      expect(early.addresses.single.type, InternetAddressType.IPv6);
      late.complete(OwnedDnsAnswer(['192.0.2.1'], 10));
    },
  );

  test(
    'transport shares cold lookups and expires on TTL and network change',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final pending = Completer<OwnedDnsAnswer>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.headers.set(HttpHeaders.connectionHeader, 'close');
        unawaited(request.response.close());
      });
      final resolver = OwnedDnsResolver(
        hosts: {'link.zolmid.com'},
        now: () => now,
        lookup: (_) async => throw StateError('unexpected lookup'),
        transportLookup: (_) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(OwnedDnsAnswer(['192.0.2.1'], 5));
        },
      );
      final client = resolver.createHttpClient(
        startConnect: (_, port) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, port),
      );
      addTearDown(() => client.close(force: true));
      Future<void> request() async {
        final response = await (await client.getUrl(
          Uri.parse('http://link.zolmid.com:${server.port}/'),
        )).close();
        await response.drain<void>();
      }

      final first = Future.wait([request(), request()]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 1);
      pending.complete(OwnedDnsAnswer(['192.0.2.1'], 5));
      await first;
      await request();
      expect(calls, 1);
      now = now.add(const Duration(seconds: 5));
      await request();
      expect(calls, 2);
      resolver.clear();
      await request();
      expect(calls, 3);
    },
  );

  test('cancelled bootstrap never applies a late socket', () async {
    final pending = Completer<OwnedDnsAnswer>();
    var dials = 0;
    final resolver = OwnedDnsResolver(
      hosts: {'link.zolmid.com'},
      lookup: (_) => pending.future,
      transportLookup: (_) => pending.future,
    );
    final client = resolver.createHttpClient(
      startConnect: (_, _) async {
        dials++;
        throw const SocketException('must not dial');
      },
    );
    addTearDown(() => client.close(force: true));
    final request = client.getUrl(Uri.parse('http://link.zolmid.com/'));
    await Future<void>.delayed(Duration.zero);
    resolver.clear();
    pending.complete(OwnedDnsAnswer(['192.0.2.1'], 30));
    await expectLater(request, throwsA(isA<SocketException>()));
    expect(dials, 0);
  });

  test('dial staggers families and cancels the losing task', () async {
    for (final addresses in [
      ['192.0.2.1', '192.0.2.2', '2001:db8::1'],
      ['2001:db8::1', '2001:db8::2', '192.0.2.1'],
    ]) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.write('ok');
        unawaited(request.response.close());
      });
      final resolver = OwnedDnsResolver(
        hosts: {'owned.invalid'},
        lookup: (_) async => OwnedDnsAnswer(addresses, 30),
      );
      final stalled = Completer<Socket>();
      final attempted = <InternetAddress>[];
      var cancelled = false;
      final client = resolver.createHttpClient(
        startConnect: (address, port) async {
          attempted.add(address);
          if (attempted.length == 1) {
            return ConnectionTask.fromSocket(stalled.future, () {
              cancelled = true;
              if (!stalled.isCompleted) {
                stalled.completeError(const SocketException('cancelled'));
              }
            });
          }
          return Socket.startConnect(InternetAddress.loopbackIPv4, port);
        },
      );
      addTearDown(() => client.close(force: true));
      final watch = Stopwatch()..start();
      final response = await (await client.getUrl(
        Uri.parse('http://owned.invalid:${server.port}/'),
      )).close();
      await response.drain<void>();
      expect(watch.elapsedMilliseconds, inInclusiveRange(200, 2000));
      expect(attempted.length, 2);
      expect(attempted.first.type, isNot(attempted.last.type));
      expect(cancelled, isTrue);
    }
  });

  test(
    'clear releases DNS callers before a stalled upstream completes',
    () async {
      final upstream = Completer<OwnedDnsAnswer>();
      final resolver = OwnedDnsResolver(
        hosts: {'owned.invalid'},
        lookup: (_) => upstream.future,
      );
      final result = resolver.resolve('owned.invalid');
      resolver.clear();
      await expectLater(
        result.timeout(const Duration(milliseconds: 100)),
        throwsA(isA<SocketException>()),
      );
      upstream.complete(OwnedDnsAnswer(['192.0.2.1'], 30));
    },
  );

  test(
    'clear between cached resolution and connection apply rejects socket',
    () async {
      final resolver = OwnedDnsResolver(
        hosts: {'owned.invalid'},
        lookup: (_) async => OwnedDnsAnswer(['192.0.2.1'], 30),
      );
      await resolver.resolve('owned.invalid');
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final accepted = Completer<Socket>();
      server.listen(accepted.complete);
      final client = resolver.createHttpClient(
        startConnect: (address, port) async {
          final task = await Socket.startConnect(
            InternetAddress.loopbackIPv4,
            port,
          );
          resolver.clear();
          return task;
        },
      );
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getUrl(Uri.parse('http://owned.invalid:${server.port}/')),
        throwsA(isA<SocketException>()),
      );
      if (accepted.isCompleted) (await accepted.future).destroy();
    },
  );

  test(
    'IPv6-only bootstrap selects an official IPv6 literal without waiting for IPv4',
    () async {
      for (final failedPrimary in [false, true]) {
        String? selected;
        final answer = await raceOwnedDnsBootstrapEndpoints(
          stagger: Duration.zero,
          exchange: (literal) async {
            if (!literal.contains(':')) {
              await Future<void>.delayed(const Duration(milliseconds: 1500));
              throw const SocketException('no IPv4 route');
            }
            if (failedPrimary && literal == '2400:3200::1') {
              throw const SocketException('primary unreachable');
            }
            selected = literal;
            return OwnedDnsAnswer(['2001:db8::10'], 30);
          },
        ).timeout(const Duration(seconds: 1));
        expect(selected, failedPrimary ? '2400:3200:baba::1' : '2400:3200::1');
        expect(answer.addresses.single.address, '2001:db8::10');
      }
    },
  );

  test('strict bootstrap tolerates either address family failing', () async {
    for (final failed in [1, 28]) {
      final answer = await bootstrapZolnitOrigin(
        query: (type) async {
          if (type == failed) throw const SocketException('synthetic outage');
          return OwnedDnsAnswer([type == 1 ? '192.0.2.1' : '2001:db8::1'], 30);
        },
      );
      expect(answer.addresses.length, 1);
      expect(answer.ttl, 30);
    }
    await expectLater(
      bootstrapZolnitOrigin(
        query: (_) async => throw const SocketException('synthetic outage'),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('strict bootstrap keeps minimum successful TTL', () async {
    final answer = await bootstrapZolnitOrigin(
      query: (type) async => OwnedDnsAnswer([
        type == 1 ? '192.0.2.1' : '2001:db8::1',
      ], type == 1 ? 60 : 10),
    );
    expect(answer.addresses.length, 2);
    expect(answer.ttl, 10);
  });

  test('scope is exact and literal answers are required', () {
    final resolver = OwnedDnsResolver(
      hosts: {'link.zolmid.com'},
      lookup: (_) async => OwnedDnsAnswer(['192.0.2.1'], 10),
    );
    expect(resolver.owns('LINK.ZOLMID.COM.'), isTrue);
    expect(resolver.owns('other.link.zolmid.com'), isFalse);
    expect(resolver.owns('example.com'), isFalse);
    for (final address in [
      'example.com',
      '127.0.0.1',
      '::',
      'ff02::1',
      'fe80::1%en0',
    ]) {
      expect(() => OwnedDnsAnswer([address], 10), throwsFormatException);
    }
    expect(() => OwnedDnsAnswer([], 10), throwsFormatException);
    expect(() => OwnedDnsAnswer(['192.0.2.1'], -1), throwsFormatException);
  });

  test(
    'coalesces lookups, honors TTL, and never serves expired answers',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      var fail = false;
      final resolver = OwnedDnsResolver(
        hosts: {'node.nodes.zolmid.com'},
        now: () => now,
        lookup: (_) async {
          calls++;
          if (fail) throw const SocketException('fixture');
          return OwnedDnsAnswer(['192.0.2.1', '2001:db8::1'], 5);
        },
      );
      await Future.wait([
        resolver.resolve('node.nodes.zolmid.com'),
        resolver.resolve('node.nodes.zolmid.com'),
      ]);
      expect(calls, 1);
      await resolver.resolve('node.nodes.zolmid.com');
      expect(calls, 1);
      now = now.add(const Duration(seconds: 5));
      fail = true;
      await expectLater(
        resolver.resolve('node.nodes.zolmid.com'),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 2);
    },
  );

  test('logout fences pending answers and invalidates cache', () async {
    final pending = Completer<OwnedDnsAnswer>();
    final resolver = OwnedDnsResolver(
      hosts: {'node.nodes.zolmid.com'},
      lookup: (_) => pending.future,
    );
    final result = resolver.resolve('node.nodes.zolmid.com');
    final check = expectLater(result, throwsA(isA<SocketException>()));
    resolver.clear();
    pending.complete(OwnedDnsAnswer(['192.0.2.1'], 60));
    await check;
  });

  test('strict failure and unowned lookup cannot use local DNS', () async {
    final resolver = OwnedDnsResolver(
      hosts: {'owned.invalid'},
      lookup: (_) async => throw const FormatException('unavailable'),
    );
    await expectLater(resolver.resolve('owned.invalid'), throwsFormatException);
    await expectLater(
      resolver.resolve('ordinary.invalid'),
      throwsFormatException,
    );
  });

  test('relay binding is exact, secret-free, and defaults to strict', () {
    final binding = OwnedDnsBinding.fromJson({
      'hosts': ['link.zolmid.com', 'node.nodes.zolmid.com'],
      'relay': 'https://link.zolmid.com/api/v1/zolnit/client/httpdns',
    });
    expect(binding.resolver.strict, isTrue);
    expect(binding.coreConfig.containsKey('authorization'), isFalse);
    binding.setAuthorization('Bearer SYNTHETIC');
    expect(binding.coreConfig['authorization'], 'Bearer SYNTHETIC');
    expect(binding.config.containsKey('authorization'), isFalse);
    binding.setAuthorization(null);
    expect(binding.coreConfig.containsKey('authorization'), isFalse);
    expect(
      () => OwnedDnsBinding.fromJson({
        'hosts': ['link.zolmid.com'],
        'relay': 'https://example.com/resolve',
      }),
      throwsFormatException,
    );
  });

  test('DNS wire decoder accepts A, empty AAAA and rejects wrong question', () {
    final packet = <int>[
      0,
      0,
      0x81,
      0x80,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      0,
      4,
      ...'link'.codeUnits,
      6,
      ...'zolmid'.codeUnits,
      3,
      ...'com'.codeUnits,
      0,
      0,
      1,
      0,
      1,
      0xc0,
      0x0c,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      30,
      0,
      4,
      192,
      0,
      2,
      1,
    ];
    final answer = decodeOwnedBootstrap(Uint8List.fromList(packet), 1);
    expect(answer.addresses.single.address, '192.0.2.1');
    expect(answer.ttl, 30);
    expect(
      () => decodeOwnedBootstrap(Uint8List.fromList(packet), 28),
      throwsFormatException,
    );
    packet[7] = 0;
    packet[packet.length - 18] = 0;
    expect(
      decodeOwnedBootstrap(Uint8List.fromList(packet), 1).addresses,
      isEmpty,
    );
  });

  test(
    'IP dial keeps original Host and rejects invalid TLS identity',
    () async {
      final context = SecurityContext()
        ..useCertificateChain('test/fixtures/update_tls_cert.pem')
        ..usePrivateKey('test/fixtures/update_tls_key.pem');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final tlsServer = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      addTearDown(() => tlsServer.close(force: true));
      tlsServer.listen((request) {
        unawaited(request.response.close());
      }, onError: (Object _) {});
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        expect(request.headers.value('host'), 'localhost:${server.port}');
        request.response.write('ok');
        unawaited(request.response.close());
      }, onError: (Object _) {});
      final resolver = OwnedDnsResolver(
        hosts: {'localhost', 'mismatch.invalid'},
        lookup: (_) async => OwnedDnsAnswer(['192.0.2.1'], 1),
      );
      final trusted = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('test/fixtures/update_tls_cert.pem');
      final client = resolver.createHttpClient(
        context: trusted,
        connect: (ips, port) {
          expect(ips.single.address, '192.0.2.1');
          return Socket.startConnect(InternetAddress.loopbackIPv4, port);
        },
      );
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(
        Uri.parse('http://localhost:${server.port}/'),
      )).close();
      expect(response.statusCode, 200);
      await response.drain<void>();
      await expectLater(
        () async => (await client.getUrl(
          Uri.parse('https://mismatch.invalid:${tlsServer.port}/'),
        )).close(),
        throwsA(isA<HandshakeException>()),
      );
    },
  );
}
