import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'constant.dart' show repository;
import 'system.dart' show ProcessRunner;

const _buildArch = String.fromEnvironment('APP_ARCH');

enum UpdatePackage {
  windowsInstaller,
  windowsPortable,
  androidApk,
  macosDmg,
  linuxAppImage,
  linuxDeb,
  linuxRpm,
  linuxPacman,
  linuxPortable,
  unsupported;

  bool get installsInPlace => switch (this) {
    windowsInstaller || androidApk || macosDmg || linuxAppImage => true,
    _ => false,
  };

  bool get isPackageManaged => switch (this) {
    linuxDeb || linuxRpm || linuxPacman => true,
    _ => false,
  };

  bool get updatesInApp => installsInPlace || isPackageManaged;
}

class UpdateTarget {
  final UpdatePackage package;
  final String arch;

  const UpdateTarget(this.package, this.arch);

  static const unsupported = UpdateTarget(UpdatePackage.unsupported, '');

  String? get assetSuffix => switch (package) {
    UpdatePackage.windowsInstaller => '-windows-$arch-setup.exe',
    UpdatePackage.windowsPortable => '-windows-$arch.zip',
    UpdatePackage.androidApk => '-android-$arch.apk',
    UpdatePackage.macosDmg => '-macos-$arch.dmg',
    UpdatePackage.linuxAppImage => '-linux-$arch.AppImage',
    UpdatePackage.linuxDeb => '-linux-$arch.deb',
    UpdatePackage.linuxRpm => '-linux-$arch.rpm',
    UpdatePackage.linuxPacman => '-linux-$arch.tar.zst',
    UpdatePackage.linuxPortable => '-linux-$arch.zip',
    UpdatePackage.unsupported => null,
  };

  @override
  bool operator ==(Object other) =>
      other is UpdateTarget && other.package == package && other.arch == arch;

  @override
  int get hashCode => Object.hash(package, arch);

  @override
  String toString() => 'UpdateTarget(${package.name}, $arch)';
}

String? _androidAbiName(Abi abi) => switch (abi) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  _ => null,
};

String? _desktopArch(Abi abi, String buildArch) {
  if (buildArch.isNotEmpty) {
    final allowed = switch (abi) {
      Abi.windowsX64 ||
      Abi.linuxX64 => const {'x64', 'x64-v1', 'x64-v2', 'x64-v3'},
      Abi.macosX64 => const {'x64'},
      Abi.windowsArm64 || Abi.linuxArm64 || Abi.macosArm64 => const {'arm64'},
      _ => const <String>{},
    };
    return allowed.contains(buildArch) ? buildArch : null;
  }
  return switch (abi) {
    Abi.windowsX64 || Abi.linuxX64 || Abi.macosX64 => 'x64',
    Abi.windowsArm64 || Abi.linuxArm64 || Abi.macosArm64 => 'arm64',
    _ => null,
  };
}

Future<UpdateTarget> detectUpdateTarget({
  String? operatingSystem,
  Abi? abi,
  String buildArch = _buildArch,
  String? executable,
  Map<String, String>? environment,
  bool Function(String path)? exists,
  ProcessRunner runProcess = Process.run,
}) async {
  final os = operatingSystem ?? Platform.operatingSystem;
  if (!const {'android', 'windows', 'macos', 'linux'}.contains(os)) {
    return UpdateTarget.unsupported;
  }
  final currentAbi = abi ?? Abi.current();
  final compatible = switch (os) {
    'android' => const {
      Abi.androidArm,
      Abi.androidArm64,
      Abi.androidX64,
      Abi.androidIA32,
    },
    'windows' => const {Abi.windowsX64, Abi.windowsArm64},
    'macos' => const {Abi.macosX64, Abi.macosArm64},
    'linux' => const {Abi.linuxX64, Abi.linuxArm64},
    _ => const <Abi>{},
  };
  if (!compatible.contains(currentAbi)) return UpdateTarget.unsupported;
  final exe = executable ?? Platform.resolvedExecutable;
  final env = environment ?? Platform.environment;
  final pathExists =
      exists ??
      (String p) =>
          FileSystemEntity.typeSync(p) != FileSystemEntityType.notFound;
  final paths = path.Context(
    style: os == 'windows' ? path.Style.windows : path.Style.posix,
  );
  final exeDir = paths.dirname(exe);

  if (os == 'android') {
    final abiName = _androidAbiName(currentAbi);
    return abiName == null
        ? UpdateTarget.unsupported
        : UpdateTarget(UpdatePackage.androidApk, abiName);
  }
  final arch = _desktopArch(currentAbi, buildArch);
  if (arch == null) {
    return UpdateTarget.unsupported;
  }
  switch (os) {
    case 'windows':
      if (pathExists(paths.join(exeDir, 'config'))) {
        return UpdateTarget(UpdatePackage.windowsPortable, arch);
      }
      if (pathExists(paths.join(exeDir, 'unins000.exe'))) {
        return UpdateTarget(UpdatePackage.windowsInstaller, arch);
      }
    case 'macos':
      if (exe.contains('.app/Contents/MacOS/')) {
        return UpdateTarget(UpdatePackage.macosDmg, arch);
      }
    case 'linux':
      if (env['APPIMAGE']?.isNotEmpty == true) {
        return UpdateTarget(UpdatePackage.linuxAppImage, arch);
      }
      if (pathExists(paths.join(exeDir, 'config'))) {
        return UpdateTarget(UpdatePackage.linuxPortable, arch);
      }
      final owner = await findLinuxPackageOwner(exe, runProcess);
      if (owner != null) {
        return UpdateTarget(owner, arch);
      }
  }
  return UpdateTarget.unsupported;
}

Future<UpdatePackage?> findLinuxPackageOwner(
  String executable,
  ProcessRunner runProcess,
) async {
  const queries = [
    (UpdatePackage.linuxDeb, 'dpkg', '-S'),
    (UpdatePackage.linuxRpm, 'rpm', '-qf'),
    (UpdatePackage.linuxPacman, 'pacman', '-Qo'),
  ];
  for (final (package, command, flag) in queries) {
    try {
      final result = await runProcess(command, [flag, executable]);
      if (result.exitCode == 0) {
        return package;
      }
    } on ProcessException {
      continue;
    }
  }
  return null;
}

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
const maxUpdatePackageBytes = 2 * 1024 * 1024 * 1024;

ReleaseAsset? _verifiedAsset(Object? asset, {required String tag}) =>
    switch (asset) {
      {
        'name': final String name,
        'url': final String url,
        'size': final int size,
        'sha256': final String sha256,
      }
          when _validAsset(name, url, size, sha256) &&
              Uri.parse(url).pathSegments[4] == tag =>
        ReleaseAsset(name: name, url: url, size: size, sha256: sha256),
      _ => null,
    };

bool _validAsset(String name, String url, int size, String digest) {
  final uri = Uri.tryParse(url);
  return RegExp(r'^FlClash-[A-Za-z0-9._+\-]+$').hasMatch(name) &&
      name.length <= 255 &&
      size > 0 &&
      size <= maxUpdatePackageBytes &&
      _sha256Pattern.hasMatch(digest) &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'github.com' &&
      uri.port == 443 &&
      uri.pathSegments.length == 6 &&
      [
        ...repository.split('/'),
        'releases',
        'download',
      ].indexed.every((part) => uri.pathSegments[part.$1] == part.$2) &&
      uri.pathSegments.last == name &&
      RegExp(r'^[vV]?\d[0-9A-Za-z._+\-]*$').hasMatch(uri.pathSegments[4]) &&
      uri.pathSegments[4].length <= 128 &&
      name.startsWith(
        'FlClash-${uri.pathSegments[4].replaceFirst(RegExp(r'^[vV]'), '')}-',
      ) &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;
}

class ReleaseManifest {
  final String tag;
  final String notes;
  final List<ReleaseAsset> assets;

  const ReleaseManifest({
    required this.tag,
    required this.notes,
    this.assets = const [],
  });

  Uri get releaseUri => Uri.parse(
    'https://github.com/$repository/releases/tag/${Uri.encodeComponent(tag)}',
  );

  factory ReleaseManifest.fromJson(Object? json) {
    if (json case {'tag': final String tag}) {
      final assets = json['assets'];
      return ReleaseManifest(
        tag: tag,
        notes: json['notes'] is String ? json['notes'] as String : '',
        assets: [
          if (assets is List)
            for (final asset in assets) ?_verifiedAsset(asset, tag: tag),
        ],
      );
    }
    throw const FormatException('Unsupported release manifest');
  }

  factory ReleaseManifest.fromGitHubRelease(Object? json) {
    if (json case {'tag_name': final String tag}) {
      final assets = json['assets'];
      return ReleaseManifest(
        tag: tag,
        notes: json['body'] is String ? json['body'] as String : '',
        assets: [
          if (assets is List)
            for (final asset in assets)
              if (asset case {
                'name': final String name,
                'browser_download_url': final String url,
                'size': final int size,
                'digest': final String digest,
              } when digest.startsWith('sha256:'))
                ?_verifiedAsset({
                  'name': name,
                  'url': url,
                  'size': size,
                  'sha256': digest.substring('sha256:'.length),
                }, tag: tag),
        ],
      );
    }
    throw const FormatException('Unsupported GitHub release');
  }
}

class ReleaseAsset {
  final String name;
  final String url;
  final int size;
  final String sha256;

  const ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.sha256,
  });

  bool get isValid => _validAsset(name, url, size, sha256);
}

class AppUpdatePlan {
  final UpdateTarget target;
  final ReleaseAsset asset;

  const AppUpdatePlan({required this.target, required this.asset});
}

AppUpdatePlan? planAppUpdate(ReleaseManifest release, UpdateTarget target) {
  final suffix = target.assetSuffix;
  if (suffix == null) {
    return null;
  }
  final version = release.tag.replaceFirst(RegExp(r'^[vV]'), '');
  final assets = release.assets
      .where(
        (asset) =>
            asset.isValid &&
            asset.name == 'FlClash-$version$suffix' &&
            Uri.parse(asset.url).pathSegments[4] == release.tag,
      )
      .toList();
  return assets.length == 1
      ? AppUpdatePlan(target: target, asset: assets.single)
      : null;
}

Uri browserDownloadUri(AppUpdatePlan? plan, {ReleaseManifest? release}) =>
    plan == null
    ? release?.releaseUri ??
          Uri.parse('https://github.com/$repository/releases/latest')
    : Uri.parse(plan.asset.url);

Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
