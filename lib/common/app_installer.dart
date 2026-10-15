import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'app_update.dart';
import 'app_update_client.dart';
import 'constant.dart' show packageName;
import 'path.dart';
import 'print.dart';
import 'system.dart' show ProcessRunner;

@visibleForTesting
const macosInstallScript = r'''
pid="$1"; dmg="$2"; app="$3"; arch="$4"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" || exit 1
[ -n "$bundle_id" ] || exit 1
while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
mnt="$(mktemp -d)" || exit 1
work="$(mktemp -d "$app.update.XXXXXX")" || { rmdir "$mnt"; exit 1; }
staging="$work/new.app"
backup="$work/previous.app"
installed=0
if hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg"; then
  matches=0; src=''
  for candidate in "$mnt"/*.app; do
    [ -d "$candidate" ] && [ ! -L "$candidate" ] || continue
    incoming_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist")" || continue
    [ "$incoming_id" = "$bundle_id" ] || continue
    executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$candidate/Contents/Info.plist")" || continue
    case "$executable" in ''|*/*|.|..) continue ;; esac
    lipo -verify_arch "$arch" "$candidate/Contents/MacOS/$executable" || continue
    matches=$((matches + 1)); src="$candidate"
  done
  if [ "$matches" -eq 1 ] && ditto "$src" "$staging"; then
    if mv "$app" "$backup"; then
      if mv "$staging" "$app"; then
        installed=1
      else
        mv "$backup" "$app"
      fi
    fi
  fi
  hdiutil detach "$mnt" -quiet || hdiutil detach "$mnt" -force -quiet
fi
rmdir "$mnt" 2>/dev/null
rm -rf "$staging" "$dmg"
[ "$installed" -eq 1 ] && rm -rf "$backup"
rmdir "$work" 2>/dev/null
open "$app"
''';

const _relaunchScript = r'''
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
exec "$2"
''';

/// Root installs a private copy it re-hashes, as the user-writable original
/// could be swapped after the check; the old Helper rejects the new Core.
@visibleForTesting
const packageInstallScript = r'''
set -eu
src="$1"; sha256="$2"; shift 2
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
pkg="$dir/$(basename "$src")"
cp -- "$src" "$pkg"
printf '%s  %s\n' "$sha256" "$pkg" | sha256sum -c --status -
DEBIAN_FRONTEND=noninteractive "$@" "$pkg"
systemctl --no-ask-password try-restart flclash-helper.service >/dev/null 2>&1 || true
''';

const _appImageRuntimeVariables = {'APPDIR', 'APPIMAGE', 'ARGV0', 'OWD'};

enum ApkInstallStatus { started, permissionDenied, failed }

enum UpdaterFailureReason { checksumMismatch, notWritable, installFailed }

class UpdaterException implements Exception {
  const UpdaterException(this.reason);

  final UpdaterFailureReason reason;

  @override
  String toString() => 'UpdaterException(${reason.name})';
}

class AppInstaller {
  const AppInstaller({AppUpdateClient? client, this.tempDirectory})
    : _client = client;

  final AppUpdateClient? _client;
  final Future<Directory> Function()? tempDirectory;
  static bool _busy = false;
  static final _verifiedDownloads = <String, ReleaseAsset>{};

  Future<T> _withOperation<T>(Future<T> Function() operation) async {
    if (_busy) throw const UpdaterException(UpdaterFailureReason.installFailed);
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  Future<File> download(
    AppUpdatePlan plan, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) => _withOperation(
    () => _download(
      plan,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    ),
  );

  Future<File> _download(
    AppUpdatePlan plan, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final suffix = plan.target.assetSuffix;
    if (!plan.asset.isValid ||
        suffix == null ||
        !plan.asset.name.endsWith(suffix)) {
      throw const UpdaterException(UpdaterFailureReason.installFailed);
    }
    final root = await _downloadDirectory(plan.target);
    final directory = Directory(
      path.join(
        root,
        '${Uri.parse(plan.asset.url).pathSegments[4]}-${plan.asset.sha256}',
      ),
    );
    await directory.create(recursive: true);
    if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('chmod', ['700', directory.path]);
      if (result.exitCode != 0) {
        throw const UpdaterException(UpdaterFailureReason.notWritable);
      }
    }
    final file = File(path.join(directory.path, plan.asset.name));
    try {
      await (_client ?? appUpdateClient).downloadFile(
        plan.asset.url,
        file.path,
        expectedSize: plan.asset.size,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        verify: (part) async {
          final actual = await sha256OfFile(part);
          if (actual != plan.asset.sha256 ||
              await part.length() != plan.asset.size) {
            await part.delete();
            throw const UpdaterException(UpdaterFailureReason.checksumMismatch);
          }
        },
      );
    } on UpdatePackageSizeException {
      throw const UpdaterException(UpdaterFailureReason.checksumMismatch);
    }
    final cancelled = cancelToken?.cancelError;
    if (cancelled != null) throw cancelled;
    _verifiedDownloads[path.normalize(file.absolute.path)] = plan.asset;
    return file;
  }

  Future<void> _verifyDownloadedFile(File file) async {
    final asset = _verifiedDownloads[path.normalize(file.absolute.path)];
    if (asset == null ||
        await file.length() != asset.size ||
        await sha256OfFile(file) != asset.sha256) {
      throw const UpdaterException(UpdaterFailureReason.checksumMismatch);
    }
  }

  Future<String> _downloadDirectory(UpdateTarget target) async {
    switch (target.package) {
      case UpdatePackage.linuxAppImage:
        final directory = path.dirname(Platform.environment['APPIMAGE']!);
        await _ensureWritable(directory);
        return path.join(directory, '.flclash-updates');
      case UpdatePackage.macosDmg:
        await _ensureWritable(path.dirname(macosAppBundle));
        return _tempDirectoryPath();
      default:
        return _tempDirectoryPath();
    }
  }

  Future<String> _tempDirectoryPath() async {
    final root = await (tempDirectory?.call() ?? appPath.tempDir.future);
    final directory = Directory(path.join(root.path, 'app-updates'));
    await directory.create(recursive: true);
    return directory.path;
  }

  Future<void> _ensureWritable(String directory) async {
    final probe = File(path.join(directory, '.flclash-update-probe-$pid'));
    try {
      await probe.writeAsString('');
      await probe.delete();
    } on FileSystemException {
      throw const UpdaterException(UpdaterFailureReason.notWritable);
    }
  }

  String get macosAppBundle =>
      path.dirname(path.dirname(path.dirname(Platform.resolvedExecutable)));

  Future<void> startWindowsInstaller(
    File setup, {
    Duration pollInterval = const Duration(milliseconds: 200),
    Duration timeout = const Duration(minutes: 2),
  }) => _withOperation(
    () => _startWindowsInstaller(setup, pollInterval, timeout),
  );

  Future<void> _startWindowsInstaller(
    File setup,
    Duration pollInterval,
    Duration timeout,
  ) async {
    await _verifyDownloadedFile(setup);
    final nonce = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final ready = File(_windowsInstallerReadyPath(setup, nonce));
    final elapsed = Stopwatch()..start();
    final process = await Process.start(
      setup.path,
      windowsInstallerArguments(setup, nonce: nonce, processId: pid),
    );
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    int? exitCode;
    unawaited(process.exitCode.then((code) => exitCode = code));
    await acknowledgeWindowsInstaller(
      ready: ready,
      nonce: nonce,
      installerExited: () => exitCode != null,
      elapsed: () => elapsed.elapsed,
      timeout: timeout,
      pollInterval: pollInterval,
    );
  }

  Future<void> startMacosInstall(File dmg) => _withOperation(() async {
    await _verifyDownloadedFile(dmg);
    await Process.start('/bin/sh', [
      '-c',
      macosInstallScript,
      'flclash-update',
      '$pid',
      dmg.path,
      macosAppBundle,
      Abi.current() == Abi.macosArm64 ? 'arm64' : 'x86_64',
    ], mode: ProcessStartMode.detached);
  });

  Future<void> replaceAppImage(File downloaded) => _withOperation(() async {
    await _verifyDownloadedFile(downloaded);
    final appImage = Platform.environment['APPIMAGE']!;
    final chmod = await Process.run('chmod', ['755', downloaded.path]);
    if (chmod.exitCode != 0) {
      throw const UpdaterException(UpdaterFailureReason.installFailed);
    }
    await downloaded.rename(appImage);
  });

  Future<void> startAppImageRelaunch() {
    return _startRelaunch(
      Platform.environment['APPIMAGE']!,
      environment: Map.of(Platform.environment)
        ..removeWhere((key, _) => _appImageRuntimeVariables.contains(key)),
    );
  }

  Future<void> startRelaunch() => _startRelaunch(Platform.resolvedExecutable);

  Future<void> _startRelaunch(
    String executable, {
    Map<String, String>? environment,
  }) async {
    await Process.start(
      '/bin/sh',
      ['-c', _relaunchScript, 'flclash-relaunch', '$pid', executable],
      mode: ProcessStartMode.detached,
      environment: environment,
      includeParentEnvironment: environment == null,
    );
  }

  Future<bool> installWithPackageManager(
    AppUpdatePlan plan,
    File package, {
    ProcessRunner runProcess = Process.run,
    bool? asRoot,
  }) => _withOperation(
    () => _installWithPackageManager(
      plan,
      package,
      runProcess: runProcess,
      asRoot: asRoot,
    ),
  );

  Future<bool> _installWithPackageManager(
    AppUpdatePlan plan,
    File package, {
    required ProcessRunner runProcess,
    bool? asRoot,
  }) async {
    final command = await packageManagerInstallCommand(
      plan.target.package,
      runProcess: runProcess,
    );
    if (command == null) {
      return false;
    }
    final script = [
      '/bin/sh',
      '-c',
      packageInstallScript,
      'flclash-update',
      package.path,
      plan.asset.sha256,
      ...command,
    ];
    final ProcessResult result;
    try {
      result = (asRoot ?? await _isRoot(runProcess))
          ? await runProcess(script.first, script.sublist(1))
          : await runProcess('pkexec', script);
    } on ProcessException catch (error) {
      commonPrint.log(
        'package update unavailable: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    if (result.exitCode != 0) {
      commonPrint.log(
        'package update exited with ${result.exitCode}: '
        '${result.stderr.toString().trim()}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    await package.delete();
    return true;
  }

  Future<ApkInstallStatus> installApk(File apk) => _withOperation(() async {
    if (!Platform.isAndroid) return ApkInstallStatus.failed;
    await _verifyDownloadedFile(apk);
    final status = await const MethodChannel(
      '$packageName/app',
    ).invokeMethod<String>('installApk', {'path': apk.path});
    return switch (status) {
      'started' => ApkInstallStatus.started,
      'permissionDenied' => ApkInstallStatus.permissionDenied,
      _ => ApkInstallStatus.failed,
    };
  });
}

@visibleForTesting
Future<void> acknowledgeWindowsInstaller({
  required File ready,
  required String nonce,
  required bool Function() installerExited,
  required Duration Function() elapsed,
  Duration timeout = const Duration(minutes: 2),
  Duration pollInterval = const Duration(milliseconds: 200),
  Future<void> Function(Duration) delay = _handshakeDelay,
}) async {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce)) {
    throw ArgumentError.value(nonce, 'nonce');
  }
  void requireActive() {
    if (installerExited() || elapsed() >= timeout) {
      throw const UpdaterException(UpdaterFailureReason.installFailed);
    }
  }

  final acknowledgement = File('${ready.path}.ack');
  final temporary = File('${acknowledgement.path}.tmp');
  var committed = false;
  try {
    while (true) {
      requireActive();
      final exists = await ready.exists();
      requireActive();
      if (exists) break;
      await delay(pollInterval);
    }
    if (await ready.readAsString() != nonce) {
      throw const UpdaterException(UpdaterFailureReason.installFailed);
    }
    requireActive();
    if (await acknowledgement.exists()) {
      throw const UpdaterException(UpdaterFailureReason.installFailed);
    }
    requireActive();
    await temporary.writeAsString(nonce, flush: true);
    requireActive();
    await temporary.rename(acknowledgement.path);
    committed = true;
  } finally {
    if (!committed) {
      try {
        if (await temporary.exists()) await temporary.delete();
      } on FileSystemException {
        // Cleanup cannot grant installation or replace the handshake failure.
      }
    }
  }
}

Future<void> _handshakeDelay(Duration duration) =>
    Future<void>.delayed(duration);

String _windowsInstallerReadyPath(File setup, String nonce) =>
    '${setup.path}.$nonce.ready';

@visibleForTesting
List<String> windowsInstallerArguments(
  File setup, {
  required String nonce,
  required int processId,
}) {
  if (processId <= 0 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce)) {
    throw ArgumentError('Expected this process PID and a 32-byte nonce');
  }
  return [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/UPDATE=1',
    '/UPDATEPID=$processId',
    '/UPDATENONCE=$nonce',
    '/UPDATEREADY=${_windowsInstallerReadyPath(setup, nonce)}',
  ];
}

Future<bool> _isRoot(ProcessRunner runProcess) async {
  final result = await runProcess('id', ['-u']);
  return result.exitCode == 0 && result.stdout.toString().trim() == '0';
}

Future<List<String>?> packageManagerInstallCommand(
  UpdatePackage package, {
  ProcessRunner runProcess = Process.run,
}) async {
  final candidates = switch (package) {
    UpdatePackage.linuxDeb => [
      ['apt-get', 'install', '-y'],
      ['dpkg', '-i'],
    ],
    UpdatePackage.linuxRpm => [
      ['dnf', 'install', '-y'],
      ['zypper', '--non-interactive', 'install', '--allow-unsigned-rpm'],
      ['rpm', '-U'],
    ],
    UpdatePackage.linuxPacman => [
      ['pacman', '-U', '--noconfirm'],
    ],
    _ => const <List<String>>[],
  };
  for (final [tool, ...arguments] in candidates) {
    try {
      final result = await runProcess('/bin/sh', [
        '-c',
        'command -v "\$1"',
        'sh',
        tool,
      ]);
      final resolved = result.stdout.toString().trim();
      final trustedPaths = {
        '/usr/bin/$tool',
        '/bin/$tool',
        '/usr/sbin/$tool',
        '/sbin/$tool',
      };
      if (result.exitCode == 0 && trustedPaths.contains(resolved)) {
        return [resolved, ...arguments];
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

const appInstaller = AppInstaller();
