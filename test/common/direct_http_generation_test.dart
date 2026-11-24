import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zolnit_client/src/http_client_io.dart';
import 'package:zolnit_client/src/http_client.dart'
    show FirstPartyNetworkObserver;
import 'package:zolnit_client/src/owned_dns.dart';

void main() {
  test(
    'network and credentials rotate sockets while POST drains without replay',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final ports = <int>[];
      final auth = <String?>[];
      final bodies = <String>[];
      final held = Completer<HttpResponse>();
      server.listen((request) async {
        ports.add(request.connectionInfo!.remotePort);
        auth.add(request.headers.value('authorization'));
        bodies.add(await utf8.decoder.bind(request).join());
        if (request.uri.path == '/held') {
          request.response.write('first');
          await request.response.flush();
          held.complete(request.response);
        } else {
          request.response.write('ok');
          await request.response.close();
        }
      });
      final resolver = OwnedDnsResolver(
        hosts: {'owned.invalid'},
        lookup: (_) async => OwnedDnsAnswer(['192.0.2.1'], 30),
      );
      final client = DirectGenerationClient(resolver: resolver);
      addTearDown(client.close);
      Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');
      final network = FirstPartyNetworkObserver(notifyFirstPartyNetworkChanged);
      await client.get(url('/one'), headers: {'authorization': 'Bearer OLD'});
      network.update(['wifi']);
      network.update(['wifi', 'vpn']);
      network.update(['wifi']);
      await client.get(url('/two'), headers: {'authorization': 'Bearer OLD'});
      expect(ports[1], ports[0]);
      final pending = client.send(
        http.Request('POST', url('/held'))
          ..headers['authorization'] = 'Bearer OLD'
          ..body = 'exactly once',
      );
      final response = await held.future;
      final streamed = await pending;
      final body = streamed.stream.bytesToString();
      network.update(['mobile']);
      await client.get(
        url('/network'),
        headers: {'authorization': 'Bearer OLD'},
      );
      expect(ports[3], isNot(ports[2]));
      await client.get(
        url('/credentials'),
        headers: {'authorization': 'Bearer NEW'},
      );
      expect(ports[4], isNot(ports[3]));
      response.write(' last');
      await response.close();
      expect(await body, 'first last');
      expect(bodies.where((body) => body == 'exactly once').length, 1);
      expect(auth, [
        'Bearer OLD',
        'Bearer OLD',
        'Bearer OLD',
        'Bearer OLD',
        'Bearer NEW',
      ]);
      await client.get(url('/reuse'), headers: {'authorization': 'Bearer NEW'});
      expect(ports[5], ports[4]);
      resolver.clear();
      await client.get(
        url('/cleared'),
        headers: {'authorization': 'Bearer NEW'},
      );
      expect(ports[6], isNot(ports[5]));
    },
  );
}
