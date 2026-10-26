import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/smart_routing.dart';

void main() {
  final start = DateTime.utc(2026, 10, 24);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));
  SmartRouteNode node(
    String id, {
    String? country = 'US',
    String? domain,
    Set<String> services = const {'ai', 'media'},
    bool verified = true,
    bool enabled = true,
    String? proxy,
    String revision = '',
  }) => SmartRouteNode(
    id: id,
    proxyName: proxy ?? id,
    countryCode: country,
    failureDomain: domain ?? id,
    services: services,
    verified: verified,
    enabled: enabled,
    revision: revision,
  );
  const ai = SmartRouteService(
    id: 'ai',
    groupName: 'AI 自动',
    isAi: true,
    allowedCountries: {'US', 'SG', 'JP', 'HK', 'ZZ'},
  );
  const media = SmartRouteService(
    id: 'media',
    groupName: '影音自动',
    allowedCountries: {'US', 'SG', 'JP', 'HK'},
  );
  late SmartRoutingEngine engine;
  var generation = 1;
  void configure(List<SmartRouteNode> nodes) => engine.configure(
    generation: generation,
    nodes: nodes,
    services: [ai, media],
  );
  void observe(
    String id,
    double? latency, {
    String service = 'ai',
    int time = 0,
    bool success = true,
    bool hard = false,
    double? loss,
    int? account,
  }) => engine.observe(
    serviceId: service,
    nodeId: id,
    generation: account ?? generation,
    sample: SmartProbeSample(
      at: at(time),
      success: success,
      latencyMs: latency,
      hardFailure: hard,
      packetLoss: loss,
    ),
  );
  SmartRouteDecision pick({String service = 'ai', int time = 0}) =>
      engine.decide(serviceId: service, now: at(time));
  void confirm(
    String? id, {
    String service = 'ai',
    int time = 0,
    int? account,
  }) => engine.confirm(
    serviceId: service,
    nodeId: id,
    now: at(time),
    generation: account ?? generation,
  );
  setUp(() {
    engine = SmartRoutingEngine();
    generation = 1;
  });

  test(
    'unknown stale probes retain only a qualified actual current selection',
    () {
      configure([node('current'), node('unmeasured', country: 'SG')]);
      observe('current', 100);
      confirm('current');
      final retained = engine.decide(
        serviceId: 'ai',
        now: at(91),
        availableNodeIds: {},
        qualifiedCurrentNodeId: 'current',
      );
      expect(retained.nodeId, 'current');
      expect(retained.reason, 'probe_unknown');
      expect(
        engine
            .decide(serviceId: 'ai', now: at(91), availableNodeIds: {})
            .nodeId,
        isNull,
      );
      observe('current', null, time: 92, success: false);
      expect(
        engine
            .decide(
              serviceId: 'ai',
              now: at(92),
              availableNodeIds: {},
              qualifiedCurrentNodeId: 'current',
            )
            .nodeId,
        isNull,
      );
    },
  );

  test(
    'AI excludes HK and builtins before scoring regardless of display name',
    () {
      configure([
        node('hk', country: 'HK', proxy: 'Tokyo fastest'),
        node('us'),
        node('direct', proxy: 'DIRECT'),
        node('unknown', country: null),
        node('unverified', verified: false),
        node('disabled', enabled: false),
        node('wrong-service', services: {'media'}),
        node('unknown-code', country: 'ZZ'),
      ]);
      observe('hk', 1);
      observe('direct', 0);
      observe('us', 100);
      expect(engine.candidates('ai').map((n) => n.id), ['us']);
      expect(pick().nodeId, 'us');
    },
  );
  test(
    'different services select different exits from their own observations',
    () {
      configure([node('us'), node('jp', country: 'JP')]);
      observe('us', 20);
      observe('jp', 120);
      observe('us', 180, service: 'media');
      observe('jp', 30, service: 'media');
      expect(pick().nodeId, 'us');
      expect(pick(service: 'media').nodeId, 'jp');
      expect(engine.metrics('ai', 'us')!.smoothedLatencyMs, 20);
      expect(engine.metrics('media', 'us')!.smoothedLatencyMs, 180);
    },
  );
  test('minimum hold and small jitter do not switch a healthy exit', () {
    configure([node('a'), node('b')]);
    observe('a', 100);
    observe('b', 150);
    confirm('a');
    observe('b', 1, time: 1);
    expect(pick(time: 1).nodeId, 'a');
    engine = SmartRoutingEngine();
    configure([node('a'), node('b')]);
    observe('a', 100);
    observe('b', 95);
    confirm('a');
    expect(pick(time: 61).nodeId, 'a');
    observe('b', 92, time: 62);
    expect(pick(time: 62).nodeId, 'a');
  });
  test(
    'enough improvement requires fresh repeated evidence and a confirmed selection',
    () {
      configure([node('a'), node('b')]);
      observe('a', 180);
      observe('b', 40);
      confirm('a');
      expect(pick(time: 61).reason, 'confirming_improvement');
      expect(pick(time: 61).nodeId, 'a');
      observe('b', 40, time: 62);
      expect(pick(time: 62).nodeId, 'b');
      confirm('b', time: 62);
      expect(pick(time: 63).nodeId, 'b');
    },
  );
  test(
    'soft failure needs confirmation and confirmed failure bypasses hold',
    () {
      configure([node('a'), node('b')]);
      observe('a', 20);
      observe('b', 100);
      confirm('a');
      observe('a', null, success: false, time: 1);
      expect(pick(time: 1).nodeId, 'a');
      observe('a', null, success: false, time: 2);
      expect(pick(time: 2).nodeId, 'b');
      expect(engine.nextProbeAt('ai', 'a'), at(17));
      confirm('b', time: 2);
      observe('a', 10, time: 18);
      expect(pick(time: 18).nodeId, 'b');
      observe('a', 10, time: 19);
      expect(pick(time: 19).nodeId, 'b');
    },
  );
  test(
    'hard failure cools a machine rather than counting variants as independent',
    () {
      configure([
        node('reality', domain: 'machine-1'),
        node('hy2', domain: 'machine-1'),
        node('other'),
      ]);
      observe('reality', 10);
      observe('hy2', 12);
      observe('other', 100);
      confirm('reality');
      observe('reality', null, success: false, hard: true, time: 1);
      expect(pick(time: 1).nodeId, 'other');
      expect(engine.nextProbeAt('ai', 'hy2'), at(16));
      expect(pick(time: 17).nodeId, 'other');
      observe('hy2', 12, time: 18);
      expect(pick(time: 18).nodeId, 'other');
    },
  );
  test('failures back off and packet loss stays unknown unless measured', () {
    configure([node('a'), node('b')]);
    observe('a', 10);
    observe('b', 50);
    expect(engine.metrics('ai', 'a')!.packetLoss, isNull);
    observe('a', 10, time: 1, loss: 0.2);
    expect(pick(time: 1).nodeId, 'b');
    observe('a', null, success: false, hard: true, time: 2);
    final first = engine.nextProbeAt('ai', 'a')!;
    observe('a', null, success: false, hard: true, time: 18);
    expect(
      engine.nextProbeAt('ai', 'a')!.difference(at(18)),
      greaterThan(first.difference(at(2))),
    );
  });
  test('no eligible or healthy nodes never chooses DIRECT', () {
    configure([node('hk', country: 'HK'), node('direct', proxy: 'DIRECT')]);
    expect(pick().nodeId, isNull);
    expect(pick().reason, 'no_eligible');
    configure([node('a')]);
    expect(pick().reason, 'awaiting_probe');
    observe('a', null, success: false, hard: true, time: 1);
    expect(pick(time: 1).nodeId, isNull);
    expect(pick(time: 1).reason, 'no_healthy');
  });
  test(
    'manual DIRECT or removed targets never silently resume automatic mode',
    () {
      configure([node('a')]);
      observe('a', 10);
      engine.setManual(serviceId: 'ai', nodeId: 'DIRECT');
      expect(pick().manual, isTrue);
      expect(pick().nodeId, 'DIRECT');
      engine.setManual(serviceId: 'ai', nodeId: 'a');
      configure([]);
      expect(pick().manual, isTrue);
      expect(pick().nodeId, isNull);
      configure([node('b')]);
      observe('b', 10, time: 1);
      expect(pick(time: 1).manual, isTrue);
      engine.resumeAutomatic('ai');
      expect(pick(time: 1).nodeId, 'b');
    },
  );
  test('new deleted and reclassified nodes immediately change eligibility', () {
    configure([node('a')]);
    observe('a', 100);
    confirm('a');
    configure([node('a'), node('b', country: 'JP')]);
    observe('b', 20, time: 61);
    expect(pick(time: 61).nodeId, 'a');
    observe('b', 20, time: 62);
    expect(pick(time: 62).nodeId, 'b');
    configure([node('b', country: 'JP')]);
    expect(pick(time: 62).nodeId, 'b');
    confirm('b', time: 62);
    configure([node('b', country: 'HK')]);
    expect(pick(time: 63).reason, 'no_eligible');
  });
  test(
    'account change clears state and rejects late probes and acknowledgements',
    () {
      configure([node('a'), node('b')]);
      observe('a', 10);
      confirm('a');
      engine.setManual(serviceId: 'ai', nodeId: 'DIRECT');
      generation = 2;
      configure([node('a'), node('b')]);
      observe('a', 1, account: 1, time: 1);
      confirm('a', account: 1, time: 1);
      expect(engine.metrics('ai', 'a'), isNull);
      expect(pick(time: 1).manual, isFalse);
      expect(pick(time: 1).reason, 'awaiting_probe');
    },
  );
  test('a proposal without Core acknowledgement does not start a hold', () {
    configure([node('a'), node('b')]);
    observe('a', 100);
    expect(pick().nodeId, 'a');
    observe('b', 10, time: 1);
    expect(pick(time: 1).nodeId, 'b');
  });
  test(
    'stale invalid or reordered samples cannot manufacture a healthy exit',
    () {
      configure([node('a')]);
      observe('a', double.nan);
      expect(engine.metrics('ai', 'a'), isNull);
      observe('a', 10, time: 1);
      expect(pick(time: 1).nodeId, 'a');
      expect(pick(time: 92).nodeId, isNull);
      observe('a', 20, time: 0);
      expect(engine.metrics('ai', 'a')!.smoothedLatencyMs, 10);
    },
  );
  test('unrelated probes cannot confirm an improvement', () {
    configure([node('a'), node('b'), node('c')]);
    observe('a', 180);
    observe('b', 40);
    observe('c', 250);
    confirm('a');
    expect(pick(time: 61).nodeId, 'a');
    observe('c', 230, time: 62);
    expect(pick(time: 62).nodeId, 'a');
    observe('b', 40, time: 63);
    expect(pick(time: 63).nodeId, 'b');
  });

  test('manual choice remains manual after policy or node changes', () {
    configure([node('a')]);
    engine.setManual(serviceId: 'ai', nodeId: 'a');
    engine.configure(
      generation: generation,
      nodes: [node('a')],
      services: [
        const SmartRouteService(
          id: 'ai',
          groupName: 'new auto',
          isAi: true,
          allowedCountries: {'US'},
        ),
      ],
    );
    expect(pick().manual, isTrue);
    expect(pick().nodeId, 'a');
    engine.configure(
      generation: generation,
      nodes: [node('a', proxy: 'replacement')],
      services: [
        const SmartRouteService(
          id: 'ai',
          groupName: 'new auto',
          isAi: true,
          allowedCountries: {'US'},
        ),
      ],
    );
    expect(pick().manual, isTrue);
    expect(pick().nodeId, isNull);
  });
  test(
    'worker-prepared candidates survive an account reset but observations do not',
    () {
      configure([node('a')]);
      observe('a', 10);
      engine.setManual(serviceId: 'ai', nodeId: 'DIRECT');
      engine.resetGeneration(2);
      expect(engine.candidates('ai').map((n) => n.id), ['a']);
      observe('a', 10, account: 1);
      expect(engine.metrics('ai', 'a'), isNull);
      expect(pick().manual, isFalse);
      expect(pick().reason, 'awaiting_probe');
    },
  );
  test('live Core membership eligibility is applied before score and hold', () {
    configure([node('a'), node('b')]);
    observe('a', 10);
    observe('b', 100);
    confirm('a');
    expect(
      engine
          .decide(serviceId: 'ai', now: at(1), availableNodeIds: {'b'})
          .nodeId,
      'b',
    );
    expect(
      engine.decide(serviceId: 'ai', now: at(1), availableNodeIds: {}).nodeId,
      isNull,
    );
  });
  test(
    'aggregate observation time cannot extend earliest provider validity',
    () {
      configure([node('a')]);
      engine.observe(
        serviceId: 'ai',
        nodeId: 'a',
        generation: generation,
        sample: SmartProbeSample(
          at: at(20),
          success: true,
          latencyMs: 10,
          validUntil: at(90),
        ),
      );
      confirm('a', time: 20);
      engine.observe(
        serviceId: 'ai',
        nodeId: 'a',
        generation: generation,
        sample: SmartProbeSample(
          at: at(80),
          success: true,
          latencyMs: 10,
          validUntil: at(90),
        ),
      );
      expect(pick(time: 89).nodeId, 'a');
      expect(pick(time: 90).nodeId, isNull);
    },
  );
}
