import 'package:flutter_test/flutter_test.dart';
import 'package:zolnit_client/src/routing_http_health.dart';
import 'package:zolnit_client/src/routing_manifest.dart';
import 'package:zolnit_client/src/routing_provider_health.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 25);
  late RoutingProviderHealthStore store;
  DateTime at(int seconds) => epoch.add(Duration(seconds: seconds));

  bool observe({
    String provider = 'chatgpt',
    String node = 'node',
    String semantics = '',
    int generation = 1,
    int sequence = 1,
    int seconds = 0,
    int status = 200,
    int latency = 12,
    String error = '',
  }) => store.observe(
    generation: generation,
    nodeId: node,
    provider: provider,
    sequence: sequence,
    observedAt: at(seconds),
    semantics: semantics,
    health: assessRoutingHttpHealth(
      provider: provider,
      statusCode: status,
      latencyMs: latency,
      error: error,
    ),
  );

  RoutingProviderAssessment assess({
    List<String> providers = const ['chatgpt'],
    String node = 'node',
    String semantics = '',
    int seconds = 0,
  }) => store.assess(
    nodeId: node,
    providers: providers,
    now: at(seconds),
    semantics: semantics,
  );

  void expectUnknown(RoutingProviderAssessment value) {
    expect(value.usableTransportSample, isFalse);
    expect(value.transportFailure, isFalse);
    expect(value.observedAt, isNull);
    expect(value.validUntil, isNull);
    expect(value.latencyMs, isNull);
  }

  setUp(() {
    store = RoutingProviderHealthStore()..resetGeneration(1);
  });

  test('all distinct providers are required; B cannot renew stale A', () {
    expectUnknown(assess());
    expect(observe(), isTrue);
    expectUnknown(assess(providers: ['chatgpt', 'claude']));
    expect(observe(provider: 'claude', seconds: 80, latency: 45), isTrue);
    final result = assess(
      providers: ['chatgpt', 'claude', 'chatgpt'],
      seconds: 89,
    );
    expect(result.usableTransportSample, isTrue);
    expect(result.transportFailure, isFalse);
    expect(result.observedAt, at(80));
    expect(result.validUntil, at(90));
    expect(result.latencyMs, 45);
    expectUnknown(assess(providers: ['chatgpt', 'claude'], seconds: 90));
    expect(
      assess(providers: ['claude'], seconds: 90).usableTransportSample,
      isTrue,
    );
  });

  test('neutral, blocked and quota results never renew either sample kind', () {
    for (final failure in [false, true]) {
      store.resetGeneration(1);
      expect(observe(error: failure ? 'timeout' : ''), isTrue);
      var sequence = 1;
      for (final status in [0, 401, 403, 404, 429, 503]) {
        expect(
          observe(sequence: ++sequence, seconds: 80, status: status),
          isTrue,
        );
      }
      final result = assess(seconds: 89);
      expect(result.usableTransportSample, !failure);
      expect(result.transportFailure, failure);
      expect(result.observedAt, at(0));
      expect(result.validUntil, at(90));
      expect(result.latencyMs, failure ? isNull : 12);
      expectUnknown(assess(seconds: 90));
    }
    store.resetGeneration(1);
    expect(observe(status: 429), isTrue);
    expectUnknown(assess());
  });

  test(
    'generation, sequence, cached replies and timestamp order are guarded',
    () {
      expect(observe(sequence: 4, seconds: 20, status: 429), isTrue);
      expect(observe(sequence: 3, seconds: 30), isFalse);
      expect(observe(sequence: 4, seconds: 30), isFalse);
      expect(observe(sequence: 5, seconds: 19), isFalse);
      expect(observe(sequence: 5, seconds: 30), isFalse);
      expectUnknown(assess(seconds: 30));
      expect(observe(sequence: 6, seconds: 30), isTrue);
      expect(observe(sequence: 6, seconds: 40, error: 'timeout'), isFalse);
      expect(observe(sequence: 2, seconds: 40, error: 'timeout'), isFalse);
      expect(assess(seconds: 40).observedAt, at(30));
      store.resetGeneration(2);
      expect(observe(generation: 1, sequence: 100, seconds: 40), isFalse);
      expectUnknown(assess(seconds: 40));
      expect(observe(generation: 2, seconds: 40), isTrue);
      expect(assess(seconds: 40).usableTransportSample, isTrue);
      store.resetGeneration(2);
      expectUnknown(assess(seconds: 40));
    },
  );

  test('failure replaces only its provider and needs actual recovery', () {
    expect(observe(), isTrue);
    expect(observe(provider: 'claude', latency: 30), isTrue);
    expect(observe(sequence: 2, seconds: 10, error: 'timeout'), isTrue);
    final failed = assess(providers: ['claude', 'chatgpt'], seconds: 15);
    expect(failed.transportFailure, isTrue);
    expect(failed.usableTransportSample, isFalse);
    expect(failed.observedAt, at(10));
    expect(failed.validUntil, at(100));
    expect(failed.latencyMs, isNull);
    expect(
      assess(providers: ['claude'], seconds: 15).usableTransportSample,
      isTrue,
    );
    expect(observe(sequence: 3, seconds: 20, status: 429), isTrue);
    expect(assess(seconds: 20).observedAt, at(10));
    expect(observe(sequence: 2, seconds: 25), isFalse);
    expect(observe(sequence: 4, seconds: 9), isFalse);
    expect(assess(seconds: 25).transportFailure, isTrue);
    expect(observe(sequence: 5, seconds: 30, latency: 0), isTrue);
    final recovered = assess(providers: ['chatgpt', 'claude'], seconds: 30);
    expect(recovered.usableTransportSample, isTrue);
    expect(recovered.transportFailure, isFalse);
    expect(recovered.observedAt, at(30));
    expect(recovered.validUntil, at(90));
    expect(recovered.latencyMs, 30);
  });

  test('future samples, empty and unknown provider sets cannot qualify', () {
    expect(observe(seconds: 10), isTrue);
    expectUnknown(assess(seconds: 9));
    expect(assess(seconds: 10).usableTransportSample, isTrue);
    expectUnknown(assess(providers: [], seconds: 10));
    expectUnknown(assess(providers: ['chatgpt', 'bogus'], seconds: 10));
    expect(observe(provider: 'bogus'), isFalse);
    expect(observe(sequence: 2, seconds: 20, error: 'timeout'), isTrue);
    expectUnknown(assess(seconds: 19));
    expect(assess(seconds: 20).transportFailure, isTrue);
    expectUnknown(assess(seconds: 110));
  });

  test(
    'nodes and full policy semantics never borrow samples or watermarks',
    () {
      expect(observe(semantics: 'policy-a', sequence: 20), isTrue);
      expectUnknown(assess(semantics: 'policy-b'));
      expectUnknown(assess(semantics: 'policy-a', node: 'other'));
      expectUnknown(assess());
      expect(observe(semantics: 'policy-b', latency: 25), isTrue);
      expect(
        observe(semantics: 'policy-a', node: 'other', latency: 40),
        isTrue,
      );
      expect(assess(semantics: 'policy-a').latencyMs, 12);
      expect(assess(semantics: 'policy-b').latencyMs, 25);
      expect(assess(semantics: 'policy-a', node: 'other').latencyMs, 40);
    },
  );

  test('bounded admission rejects bogus providers without consuming slots', () {
    for (var index = 0; index < 5000; index++) {
      expect(observe(node: 'bogus-$index', provider: 'bogus-$index'), isFalse);
    }
    for (var index = 0; index < 4096; index++) {
      expect(observe(node: 'node-$index'), isTrue);
    }
    expect(observe(node: 'overflow'), isFalse);
    for (final provider in routingProviderProbeUrls.keys) {
      expect(
        observe(
          node: 'node-0',
          provider: provider,
          sequence: 2,
          status: provider == 'operator' ? 204 : 200,
        ),
        isTrue,
      );
    }
    for (var index = 1; index < 16; index++) {
      expect(observe(node: 'node-0', semantics: 'policy-$index'), isTrue);
    }
    expect(observe(node: 'node-0', semantics: 'overflow'), isFalse);
    expect(observe(node: '', sequence: 3), isFalse);
    expect(observe(semantics: 'x' * 4097), isFalse);
    store.resetGeneration(2);
    expect(observe(node: 'overflow', generation: 2), isTrue);
  });

  test('custom lifetime controls expiration', () {
    store = RoutingProviderHealthStore(lifetime: const Duration(seconds: 5))
      ..resetGeneration(1);
    expect(observe(), isTrue);
    expect(assess(seconds: 4).validUntil, at(5));
    expectUnknown(assess(seconds: 5));
    expect(
      () => RoutingProviderHealthStore(lifetime: Duration.zero),
      throwsArgumentError,
    );
  });
}
