import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'client_bundle_fixture.dart';

final _fingerprint = List.filled(64, 'a').join();
final _changedFingerprint = List.filled(64, 'b').join();
Json _routing(Json raw) => raw['routing'] as Json;
Json _node(Json raw) => (_routing(raw)['nodes'] as List).last as Json;
Json _outbound(Json raw) => (raw['outbounds'] as List).last as Json;
Json _egress(Json raw) => _node(raw)['final_egress'] as Json;
Json _fixture() {
  final raw = clientBundleFixture();
  _routing(raw)['nodes'] = [_node(raw)];
  _egress(raw).addAll({
    'source': 'operator_allowlist',
    'configuration_fingerprint': _fingerprint,
  });
  _outbound(raw)['configuration_fingerprint'] = _fingerprint;
  return raw;
}

ZolnitClientBundle _parse(Json raw, {int at = 1001}) =>
    ZolnitClientBundle.parse(raw, now: bundleTime(at));
SmartRoutingEngine _engine(ZolnitClientBundle bundle) =>
    SmartRoutingEngine()..configure(
      generation: 1,
      nodes: bundle.routingManifest.nodes,
      services: bundle.routingManifest.services.map((s) => s.route).toList(),
    );

void main() {
  test('Dart and Go use the same legacy and fingerprint digest vectors', () {
    expect(
      _parse(clientBundleFixture()).routingSha256,
      '6c6bac0952112c0e3373512b12a085c149a7e5211f3e3dd6df83216f3e33a502',
    );
    expect(
      _parse(_fixture()).routingSha256,
      '01ebb7bc1cd8ea2600c3aae1718f05f31dea44fc5be4ef2282ebb0079a98af58',
    );
  });

  test('manifest callers must supply authorized outbound fingerprints', () {
    final bundle = _parse(_fixture());
    final proxyNames = bundle.outbounds.map((o) => o.proxyName).toSet();
    final groupNames = bundle.routingManifest.services
        .map((s) => s.groupName)
        .toSet();
    expect(
      SmartRoutingManifest.parse(
        bundle.routingJson,
        proxyNames: proxyNames,
        groupNames: groupNames,
      )!.nodes,
      isEmpty,
    );
    expect(
      SmartRoutingManifest.parse(
        bundle.routingJson,
        proxyNames: proxyNames,
        groupNames: groupNames,
        outboundFingerprints: {
          for (final outbound in bundle.outbounds)
            if (outbound.configurationFingerprint != null)
              outbound.id: outbound.configurationFingerprint!,
        },
      )!.nodes,
      hasLength(1),
    );
  });

  test('bound qualification round trips and needs independent live health', () {
    final raw = _fixture();
    final bundle = _parse(raw);
    expect(
      bundle.routingManifest.nodes.single.qualificationSource,
      'operator_allowlist',
    );
    expect(bundle.outbounds.last.configurationFingerprint, _fingerprint);
    expect(_parse(bundle.toJson()).toJson(), bundle.toJson());
    final engine = _engine(bundle);
    expect(engine.candidates('ai').single.id, 'vless:7');
    expect(
      engine.decide(serviceId: 'ai', now: bundleTime(1001)).nodeId,
      isNull,
    );
    engine.observe(
      serviceId: 'ai',
      nodeId: 'vless:7',
      generation: 1,
      sample: SmartProbeSample(
        at: bundleTime(1001),
        success: true,
        latencyMs: 20,
      ),
    );
    expect(
      engine.decide(serviceId: 'ai', now: bundleTime(1001)).nodeId,
      'vless:7',
    );
    expect(
      engine.decide(serviceId: 'ai', now: bundleTime(1200)).nodeId,
      isNull,
    );
  });

  test('missing malformed and mismatched proof retain manual outbounds', () {
    for (final value in [
      null,
      '',
      'A' * 64,
      'a' * 63,
      'a' * 64 + '\n',
      7,
      _changedFingerprint,
    ]) {
      for (final outbound in [false, true]) {
        final raw = _fixture();
        (outbound
                ? _outbound(raw)
                : _egress(raw))['configuration_fingerprint'] =
            value;
        final bundle = _parse(raw);
        expect(bundle.outbounds, hasLength(3));
        expect(bundle.document, raw['connection']['document']);
        expect(bundle.routingManifest.nodes, isEmpty);
        expect(_engine(bundle).candidates('ai'), isEmpty);
      }
    }
  });

  test(
    'fingerprint-only change invalidates metadata and prior qualification',
    () {
      final raw = _fixture();
      final before = _parse(raw);
      final engine = _engine(before);
      engine.observe(
        serviceId: 'ai',
        nodeId: 'vless:7',
        generation: 1,
        sample: SmartProbeSample(
          at: bundleTime(1001),
          success: true,
          latencyMs: 20,
        ),
      );
      _outbound(raw)['configuration_fingerprint'] = _changedFingerprint;
      final unqualified = _parse(raw);
      expect(unqualified.connectionSha256, before.connectionSha256);
      expect(unqualified.routingJson, before.routingJson);
      expect(unqualified.routingSha256, isNot(before.routingSha256));
      expect(unqualified.routingManifest.nodes, isEmpty);
      _egress(raw)['configuration_fingerprint'] = _changedFingerprint;
      final after = _parse(raw);
      expect(
        after.routingManifest.nodes.single.identity,
        isNot(before.routingManifest.nodes.single.identity),
      );
      engine.configure(
        generation: 1,
        nodes: after.routingManifest.nodes,
        services: after.routingManifest.services.map((s) => s.route).toList(),
      );
      expect(engine.metrics('ai', 'vless:7'), isNull);
      expect(
        engine.decide(serviceId: 'ai', now: bundleTime(1002)).nodeId,
        isNull,
      );
      _egress(raw)['source'] = 'operator_verified';
      final legacy = _parse(raw);
      expect(
        legacy.routingManifest.nodes.single.identity,
        isNot(after.routingManifest.nodes.single.identity),
      );
    },
  );

  test('confirmation does not age out while each delivered lease is fresh', () {
    final raw = _fixture();
    _egress(raw)['verified_at'] = 1;
    final before = _parse(raw);
    const later = 1001 + 10 * 86400;
    raw['issued_at'] = later;
    raw['expires_at'] = later + 300;
    final renewed = _parse(raw, at: later);
    expect(
      renewed.routingManifest.nodes.single.identity,
      before.routingManifest.nodes.single.identity,
    );
    expect(renewed.routingSha256, before.routingSha256);
    expect(_engine(renewed).candidates('ai'), hasLength(1));
    expect(() => _parse(raw, at: later + 300), throwsA(isA<ClientFailure>()));
  });

  test(
    'legacy sources preserve original hash and do not require fingerprints',
    () {
      for (final source in ['operator_verified', 'egress_probe']) {
        final raw = clientBundleFixture();
        _egress(raw)['source'] = source;
        final bundle = _parse(raw);
        expect(bundle.routingManifest.nodes, hasLength(2));
        expect(
          bundle.routingSha256,
          sha256
              .convert(utf8.encode(jsonEncode(bundle.routingJson)))
              .toString(),
        );
      }
    },
  );

  test('country service revision enabled and verified gates still apply', () {
    for (final country in ['JP', 'SG', 'US']) {
      final raw = _fixture();
      _egress(raw)['country'] = country;
      expect(_engine(_parse(raw)).candidates('ai'), hasLength(1));
    }
    for (final patch in <void Function(Json)>[
      (r) => _egress(r)['country'] = 'HK',
      (r) => _egress(r)['country'] = 'DE',
      (r) => _egress(r)['country'] = 'ZZ',
      (r) => _egress(r)['verified'] = false,
      (r) => _node(r)['revision'] = '',
      (r) => _node(r)['enabled'] = false,
      (r) => _node(r)['services'] = ['media'],
      (r) => _node(r)['services'] = ['unknown'],
    ]) {
      final raw = _fixture();
      patch(raw);
      final bundle = _parse(raw);
      expect(bundle.outbounds, hasLength(3));
      expect(_engine(bundle).candidates('ai'), isEmpty);
    }
    for (final patch in <void Function(Json)>[
      (r) => _node(r)['id'] = 'unknown:1',
      (r) => _node(r)['proxy_name'] = 'wrong',
      (r) => _node(r)['failure_domain'] = '',
      (r) => r['account_id'] = 'other',
    ]) {
      final raw = _fixture();
      patch(raw);
      expect(
        () => ZolnitClientBundle.parse(
          raw,
          now: bundleTime(1001),
          expectedAccountId: 'account-1',
        ),
        throwsA(isA<ClientFailure>()),
      );
    }
  });
}
