import 'package:fl_clash/features/connection/connection.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerInfo _tracker({
  required String id,
  String process = 'curl',
  String network = 'tcp',
  List<String> chains = const ['Proxy'],
  String rule = 'DOMAIN',
  String rulePayload = 'example.com',
}) {
  return TrackerInfo(
    id: id,
    start: DateTime.utc(2026),
    metadata: Metadata(process: process, network: network),
    chains: chains,
    rule: rule,
    rulePayload: rulePayload,
  );
}

void main() {
  group('TrackerInfoFilter', () {
    test('keeps the four filter dimensions independent', () {
      const empty = TrackerInfoFilter();

      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);

      final filter = empty
          .add(TrackerInfoFilterType.process, 'curl')
          .add(TrackerInfoFilterType.chain, 'Proxy')
          .add(TrackerInfoFilterType.network, 'tcp')
          .add(TrackerInfoFilterType.rule, 'DOMAIN(example.com)');

      expect(filter.isEmpty, isFalse);
      expect(filter.isNotEmpty, isTrue);
      for (final entry in filter.entries) {
        expect(filter.contains(entry.type, entry.value), isTrue);
      }
      expect(filter.entries.map((entry) => (entry.type, entry.value)), [
        (TrackerInfoFilterType.process, 'curl'),
        (TrackerInfoFilterType.chain, 'Proxy'),
        (TrackerInfoFilterType.network, 'tcp'),
        (TrackerInfoFilterType.rule, 'DOMAIN(example.com)'),
      ]);
      expect(empty.isEmpty, isTrue);
    });

    test('toggle and remove return updated copies', () {
      const original = TrackerInfoFilter(
        processes: {'curl'},
        chains: {'Proxy'},
        networks: {'tcp'},
        rules: {'MATCH'},
      );

      for (final entry in original.entries) {
        final removed = original.toggle(entry.type, entry.value);
        expect(removed.contains(entry.type, entry.value), isFalse);
        expect(original.contains(entry.type, entry.value), isTrue);
        expect(
          removed
              .toggle(entry.type, entry.value)
              .contains(entry.type, entry.value),
          isTrue,
        );
        expect(
          original
              .remove(entry.type, entry.value)
              .contains(entry.type, entry.value),
          isFalse,
        );
      }

      final copied = original.copyWith(processes: {'wget'});
      expect(copied.processes, {'wget'});
      expect(copied.chains, original.chains);
      expect(copied.networks, original.networks);
      expect(copied.rules, original.rules);
    });

    test('matches every active dimension and filters an iterable', () {
      final matching = _tracker(
        id: 'matching',
        chains: const ['Selector', 'Proxy'],
      );
      final otherProcess = _tracker(id: 'process', process: 'browser');
      final otherChain = _tracker(id: 'chain', chains: const ['Direct']);
      final otherNetwork = _tracker(id: 'network', network: 'udp');
      final otherRule = _tracker(id: 'rule', rule: 'MATCH', rulePayload: '');
      const filter = TrackerInfoFilter(
        processes: {'curl'},
        chains: {'Proxy'},
        networks: {'tcp'},
        rules: {'DOMAIN(example.com)'},
      );

      expect(const TrackerInfoFilter().matches(matching), isTrue);
      expect(filter.matches(matching), isTrue);
      expect(filter.matches(otherProcess), isFalse);
      expect(filter.matches(otherChain), isFalse);
      expect(filter.matches(otherNetwork), isFalse);
      expect(filter.matches(otherRule), isFalse);
      expect(
        [
          matching,
          otherProcess,
          otherChain,
          otherNetwork,
          otherRule,
        ].withTrackerFilter(filter).map((item) => item.id),
        ['matching'],
      );
      expect(getTrackerInfoRuleText(matching), 'DOMAIN(example.com)');
      expect(getTrackerInfoRuleText(otherRule), 'MATCH');
    });
  });
}
