import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

void main() {
  test(
    'PHP producer v1 bundle preserves hash, mapping, short TTL and AI policy',
    () {
      final raw =
          jsonDecode(
                File(
                  'test/fixtures/qualified-bundle-producer-v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final now = DateTime.fromMillisecondsSinceEpoch(1001 * 1000, isUtc: true);
      final bundle = ZolnitClientBundle.parse(
        raw['data'] as Map<String, dynamic>,
        now: now,
        expectedAccountId: '4242',
      );
      expect(bundle.outbounds, hasLength(20));
      expect(bundle.routingManifest.nodes, hasLength(6));
      expect(bundle.expiresAt.difference(bundle.issuedAt).inSeconds, 150);
      final engine = SmartRoutingEngine()
        ..configure(
          generation: 1,
          nodes: bundle.routingManifest.nodes,
          services: bundle.routingManifest.services
              .map((service) => service.route)
              .toList(),
        );
      expect(engine.candidates('ai'), hasLength(6));
      expect(
        engine.candidates('ai').any((node) => node.countryCode == 'HK'),
        isFalse,
      );
      expect(
        () => ZolnitClientBundle.parse(
          raw['data'] as Map<String, dynamic>,
          now: now,
          expectedAccountId: 'other-account',
        ),
        throwsA(isA<ClientFailure>()),
      );
      expect(
        () => ZolnitClientBundle.parse(
          raw['data'] as Map<String, dynamic>,
          now: DateTime.fromMillisecondsSinceEpoch(1150 * 1000, isUtc: true),
          expectedAccountId: '4242',
        ),
        throwsA(isA<ClientFailure>()),
      );
    },
  );
}
