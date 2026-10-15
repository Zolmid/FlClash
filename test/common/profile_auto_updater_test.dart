import 'dart:async';

import 'package:fl_clash/common/profile_auto_updater.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(
  int id, {
  DateTime? updated,
  Duration interval = const Duration(minutes: 20),
}) => Profile(
  id: id,
  type: ProfileType.url,
  url: 'https://example.com/$id',
  autoUpdateDuration: interval,
  lastUpdateDate: updated,
);

void main() {
  testWidgets(
    'a manual refresh delays the next automatic refresh by the full interval',
    (tester) async {
      final now = tester.binding.clock.now;
      var profiles = [_profile(1, updated: now())];
      var calls = 0;
      final updater = ProfileAutoUpdater(
        profiles: () => profiles,
        now: now,
        update: (_) async => calls++,
        onError: (error) => fail('$error'),
      );
      addTearDown(updater.dispose);
      updater.start();
      await tester.pump(const Duration(minutes: 19));
      profiles = [profiles.single.copyWith(lastUpdateDate: now())];
      updater.reschedule();
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 0);
      await tester.pump(const Duration(minutes: 19));
      expect(calls, 1);
      updater.dispose();
    },
  );

  testWidgets('each profile follows its own latest update time', (
    tester,
  ) async {
    final now = tester.binding.clock.now;
    final calls = <int>[];
    final profiles = [
      _profile(1, updated: now().subtract(const Duration(minutes: 4))),
      _profile(2, updated: now().subtract(const Duration(minutes: 3))),
    ];
    final updater = ProfileAutoUpdater(
      profiles: () => profiles,
      now: now,
      update: (profile) async => calls.add(profile.id),
      onError: (error) => fail('$error'),
    );
    addTearDown(updater.dispose);
    updater.start();
    await tester.pump(const Duration(minutes: 16));
    expect(calls, [1]);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, [1, 2]);
    updater.dispose();
  });

  testWidgets('a failed manual refresh postpones the automatic retry', (
    tester,
  ) async {
    final now = tester.binding.clock.now;
    var attempted = now().subtract(const Duration(minutes: 30));
    var calls = 0;
    final updater = ProfileAutoUpdater(
      profiles: () => [
        _profile(1, updated: now().subtract(const Duration(hours: 1))),
      ],
      now: now,
      lastAttempt: (_) => attempted,
      update: (_) async => calls++,
      onError: (error) => fail('$error'),
    );
    addTearDown(updater.dispose);
    attempted = now();
    updater.start();
    await tester.pump(const Duration(minutes: 19));
    expect(calls, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
    updater.dispose();
  });

  testWidgets('overdue startup and failed attempts never create a retry loop', (
    tester,
  ) async {
    final now = tester.binding.clock.now;
    var calls = 0;
    final errors = <Object>[];
    final updater = ProfileAutoUpdater(
      profiles: () => [_profile(1)],
      now: now,
      update: (_) async {
        calls++;
        throw StateError('offline');
      },
      onError: errors.add,
    );
    addTearDown(updater.dispose);
    updater.start();
    await tester.pump(Duration.zero);
    expect(calls, 1);
    await updater.check();
    expect(calls, 1);
    await tester.pump(const Duration(minutes: 20));
    expect(calls, 2);
    expect(errors, hasLength(2));
    updater.dispose();
  });

  testWidgets('interval edits and disabling profiles reschedule the timer', (
    tester,
  ) async {
    final now = tester.binding.clock.now;
    var calls = 0;
    var profiles = [
      _profile(1, updated: now(), interval: const Duration(hours: 6)),
    ];
    final updater = ProfileAutoUpdater(
      profiles: () => profiles,
      now: now,
      update: (_) async => calls++,
      onError: (error) => fail('$error'),
    );
    addTearDown(updater.dispose);
    updater.start();
    await tester.pump(const Duration(minutes: 10));
    profiles = [
      profiles.single.copyWith(autoUpdateDuration: const Duration(minutes: 20)),
    ];
    updater.reschedule();
    await tester.pump(const Duration(minutes: 10));
    expect(calls, 1);
    profiles = [profiles.single.copyWith(autoUpdate: false)];
    updater.reschedule();
    await tester.pump(const Duration(days: 1));
    expect(calls, 1);
    updater.dispose();
  });

  testWidgets(
    'resume catches up once and overlapping checks share the active batch',
    (tester) async {
      final start = tester.binding.clock.now();
      var now = start;
      var calls = 0;
      final pending = Completer<void>();
      final updater = ProfileAutoUpdater(
        profiles: () => [_profile(1, updated: start)],
        now: () => now,
        update: (_) {
          calls++;
          return pending.future;
        },
        onError: (error) => fail('$error'),
      );
      addTearDown(updater.dispose);
      updater.start();
      now = start.add(const Duration(minutes: 65));
      final check = updater.check();
      await updater.check();
      updater.reschedule();
      expect(calls, 1);
      pending.complete();
      await check;
      await updater.check();
      expect(calls, 1);
      updater.dispose();
      await tester.pump(const Duration(days: 1));
      expect(calls, 1);
    },
  );
}
