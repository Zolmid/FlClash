import 'dart:io';

import 'package:fl_clash/common/app_installer.dart';
import 'package:test/test.dart';

const _nonce =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _timeout = Duration(seconds: 2);

void main() {
  late Directory directory;
  late File ready;
  late File acknowledgement;
  late File temporary;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash-windows-ready-');
    ready = File('${directory.path}/setup.exe.$_nonce.ready');
    acknowledgement = File('${ready.path}.ack');
    temporary = File('${acknowledgement.path}.tmp');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<void> acknowledge({
    bool Function()? exited,
    Duration Function()? elapsed,
    Future<void> Function(Duration)? delay,
  }) => acknowledgeWindowsInstaller(
    ready: ready,
    nonce: _nonce,
    installerExited: exited ?? () => false,
    elapsed: elapsed ?? () => Duration.zero,
    timeout: _timeout,
    pollInterval: const Duration(seconds: 1),
    delay: delay ?? (_) async {},
  );

  Future<void> expectUnacknowledged() async {
    expect(await acknowledgement.exists(), isFalse);
    expect(await temporary.exists(), isFalse);
  }

  test(
    'publishes an exact nonce acknowledgement after matching readiness',
    () async {
      await ready.writeAsString(_nonce);

      await acknowledge();

      expect(await acknowledgement.readAsString(), _nonce);
      expect(await temporary.exists(), isFalse);
      expect(await ready.readAsString(), _nonce);
    },
  );

  test('a late ready file cannot bypass the parent deadline', () async {
    var elapsed = Duration.zero;

    await expectLater(
      acknowledge(
        elapsed: () => elapsed,
        delay: (duration) async {
          elapsed += duration;
          if (elapsed >= _timeout) {
            await ready.writeAsString(_nonce);
          }
        },
      ),
      throwsA(isA<UpdaterException>()),
    );

    expect(await ready.readAsString(), _nonce);
    await expectUnacknowledged();
  });

  test('rejects an already-present ready file after the deadline', () async {
    await ready.writeAsString(_nonce);

    await expectLater(
      acknowledge(elapsed: () => _timeout),
      throwsA(isA<UpdaterException>()),
    );

    await expectUnacknowledged();
  });

  test(
    'does not acknowledge an installer that exited while readiness arrived',
    () async {
      var exited = false;

      await expectLater(
        acknowledge(
          exited: () => exited,
          delay: (_) async {
            await ready.writeAsString(_nonce);
            exited = true;
          },
        ),
        throwsA(isA<UpdaterException>()),
      );

      await expectUnacknowledged();
    },
  );

  for (final value in ['another-nonce', '$_nonce\n']) {
    test('refuses readiness with a nonmatching nonce ($value)', () async {
      await ready.writeAsString(value);

      await expectLater(acknowledge(), throwsA(isA<UpdaterException>()));

      await expectUnacknowledged();
    });
  }

  test(
    'rechecks the deadline after flushing the temporary acknowledgement',
    () async {
      await ready.writeAsString(_nonce);

      await expectLater(
        acknowledge(
          elapsed: () => temporary.existsSync() ? _timeout : Duration.zero,
        ),
        throwsA(isA<UpdaterException>()),
      );

      await expectUnacknowledged();
    },
  );

  test(
    'rechecks installer exit after flushing the temporary acknowledgement',
    () async {
      await ready.writeAsString(_nonce);

      await expectLater(
        acknowledge(exited: temporary.existsSync),
        throwsA(isA<UpdaterException>()),
      );

      await expectUnacknowledged();
    },
  );

  test(
    'an acknowledgement write failure never publishes the final marker',
    () async {
      await ready.writeAsString(_nonce);
      await Directory(temporary.path).create();

      await expectLater(acknowledge(), throwsA(isA<FileSystemException>()));

      expect(await acknowledgement.exists(), isFalse);
      expect(await temporary.exists(), isFalse);
    },
  );

  test('does not overwrite an existing acknowledgement', () async {
    await ready.writeAsString(_nonce);
    await acknowledgement.writeAsString('previous-attempt');

    await expectLater(acknowledge(), throwsA(isA<UpdaterException>()));

    expect(await acknowledgement.readAsString(), 'previous-attempt');
    expect(await temporary.exists(), isFalse);
  });

  test(
    'a new attempt leaves a late older attempt isolated and unacknowledged',
    () async {
      const oldNonce =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final setup = File('${directory.path}/setup.exe');
      final oldArguments = windowsInstallerArguments(
        setup,
        nonce: oldNonce,
        processId: 42,
      );
      final newArguments = windowsInstallerArguments(
        setup,
        nonce: _nonce,
        processId: 42,
      );
      String readyPath(List<String> arguments) => arguments
          .singleWhere((argument) => argument.startsWith('/UPDATEREADY='))
          .substring('/UPDATEREADY='.length);
      final oldReady = File(readyPath(oldArguments));
      expect(readyPath(newArguments), ready.path);
      expect(oldReady.path, isNot(ready.path));
      await oldReady.writeAsString(oldNonce);
      await ready.writeAsString(_nonce);

      await acknowledge();

      expect(await acknowledgement.readAsString(), _nonce);
      expect(await oldReady.readAsString(), oldNonce);
      expect(await File('${oldReady.path}.ack').exists(), isFalse);
    },
  );

  test('a retry does not clear a different attempt acknowledgement', () async {
    const oldNonce =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final oldReady = File('${directory.path}/setup.exe.$oldNonce.ready');
    final oldAcknowledgement = File('${oldReady.path}.ack');
    await oldReady.writeAsString(oldNonce);
    await oldAcknowledgement.writeAsString(oldNonce);
    await ready.writeAsString(_nonce);

    await acknowledge();

    expect(await acknowledgement.readAsString(), _nonce);
    expect(await oldAcknowledgement.readAsString(), oldNonce);
    expect(await oldReady.readAsString(), oldNonce);
  });

  test(
    'successful publication is the commit point even if time or exit changes afterwards',
    () async {
      await ready.writeAsString(_nonce);

      await acknowledge(
        elapsed: () => acknowledgement.existsSync() ? _timeout : Duration.zero,
        exited: acknowledgement.existsSync,
      );

      expect(await acknowledgement.readAsString(), _nonce);
      expect(await temporary.exists(), isFalse);
    },
  );
}
