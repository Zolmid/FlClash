import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'system.dart' show ProcessRunner;

const websiteReleaseManifestUrl =
    'https://link.zolmid.com/client/releases.json';
const _websiteDownloadRoot = 'https://link.zolmid.com/client/downloads';
const websiteReleasePageUrl = 'https://link.zolmid.com';
const maxWebsiteManifestBytes = 1024 * 1024;

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
              Uri.parse(url).pathSegments[2] == tag =>
        ReleaseAsset(name: name, url: url, size: size, sha256: sha256),
      _ => null,
    };

bool _validAsset(String name, String url, int size, String digest) {
  final uri = Uri.tryParse(url);
  return RegExp(r'^ZolNit-[A-Za-z0-9._+\-]+$').hasMatch(name) &&
      name.length <= 255 &&
      size > 0 &&
      size <= maxUpdatePackageBytes &&
      _sha256Pattern.hasMatch(digest) &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'link.zolmid.com' &&
      uri.port == 443 &&
      uri.pathSegments.length == 4 &&
      uri.pathSegments[0] == 'client' &&
      uri.pathSegments[1] == 'downloads' &&
      uri.pathSegments.last == name &&
      _validVersion(uri.pathSegments[2]) &&
      _validPackageName(name, uri.pathSegments[2]) &&
      name.startsWith(
        'ZolNit-${uri.pathSegments[2].replaceFirst(RegExp(r'^[vV]'), '')}-',
      ) &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      !uri.hasQuery &&
      uri.toString() == '$_websiteDownloadRoot/${uri.pathSegments[2]}/$name';
}

bool _validVersion(String tag) {
  if (!RegExp(
    r'^v(?:0|[1-9]\d{0,9})\.(?:0|[1-9]\d{0,9})\.(?:0|[1-9]\d{0,9})$',
  ).hasMatch(tag)) {
    return false;
  }
  return tag
      .substring(1)
      .split('.')
      .every((part) => int.parse(part) <= 2147483647);
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

  Uri get releaseUri => Uri.parse(websiteReleasePageUrl);

  factory ReleaseManifest.fromJson(Object? json) {
    if (json case {'tag': final String tag} when _validVersion(tag)) {
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
    if (json case {'tag_name': final String tag} when _validVersion(tag)) {
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

List<ReleaseManifest>? parseWebsiteReleases(Object? value) {
  if (value is! Map ||
      value['schema_version'] is! int ||
      value['schema_version'] != 1 ||
      value['app_id'] != 'com.zolmid.zolnit' ||
      value['updates_enabled'] is! bool ||
      value['releases'] is! List ||
      value.keys.any(
        (key) => !const {
          'schema_version',
          'app_id',
          'updates_enabled',
          'releases',
        }.contains(key),
      )) {
    throw const FormatException('Unsupported website update metadata');
  }
  final entries = value['releases'] as List;
  if (entries.length > 30) {
    throw const FormatException('Too many website releases');
  }
  if (value['updates_enabled'] == false || entries.isEmpty) {
    if (entries.isNotEmpty && value['updates_enabled'] == false) {
      throw const FormatException('Disabled updates must have no releases');
    }
    return null;
  }
  final releases = <ReleaseManifest>[];
  for (final entry in entries) {
    if (entry is! Map ||
        entry['tag'] is! String ||
        entry['assets'] is! List ||
        (entry['assets'] as List).isEmpty ||
        (entry['assets'] as List).length > 64 ||
        entry['notes'] is! String ||
        (entry['notes'] as String).runes.length > 32768 ||
        entry.keys.any(
          (key) => !const {'tag', 'notes', 'assets'}.contains(key),
        )) {
      throw const FormatException('Invalid website release');
    }
    final rawAssets = entry['assets'] as List;
    if (rawAssets.any(
      (asset) =>
          asset is! Map ||
          asset.keys.any(
            (key) => !const {'name', 'url', 'size', 'sha256'}.contains(key),
          ),
    )) {
      throw const FormatException('Invalid website release assets');
    }
    final release = ReleaseManifest.fromJson(entry);
    if (release.assets.length != rawAssets.length ||
        release.assets.map((asset) => asset.name).toSet().length !=
            release.assets.length ||
        release.assets.any(
          (asset) => !_validPackageName(asset.name, release.tag),
        )) {
      throw const FormatException('Invalid website release assets');
    }
    if (releases.any((existing) => existing.tag == release.tag)) {
      throw const FormatException('Duplicate website release');
    }
    releases.add(release);
  }
  return releases;
}

List<ReleaseManifest>? decodeWebsiteReleases(String source) {
  if (utf8.encode(source).length > maxWebsiteManifestBytes) {
    throw const FormatException('Website metadata is too large');
  }
  _WebsiteJSON(source).validate();
  return parseWebsiteReleases(jsonDecode(source));
}

class _WebsiteJSON {
  _WebsiteJSON(this.source);
  final String source;
  var position = 0;

  void validate() {
    _value(0);
    _space();
    if (position != source.length) _invalid();
  }

  Never _invalid() => throw const FormatException('Invalid website JSON');

  void _space() {
    while (position < source.length &&
        const {9, 10, 13, 32}.contains(source.codeUnitAt(position))) {
      position++;
    }
  }

  bool _take(int character) {
    _space();
    if (position >= source.length || source.codeUnitAt(position) != character) {
      return false;
    }
    position++;
    return true;
  }

  String _string() {
    _space();
    final start = position;
    if (!_take(34)) _invalid();
    while (position < source.length) {
      final character = source.codeUnitAt(position++);
      if (character == 92) {
        position++;
      } else if (character == 34) {
        return jsonDecode(source.substring(start, position)) as String;
      }
    }
    return _invalid();
  }

  void _value(int depth) {
    if (depth > 32) _invalid();
    _space();
    if (position >= source.length) _invalid();
    final character = source.codeUnitAt(position);
    if (character == 123) {
      position++;
      final keys = <String>{};
      if (_take(125)) return;
      do {
        if (!keys.add(_string()) || !_take(58)) _invalid();
        _value(depth + 1);
        if (_take(125)) return;
      } while (_take(44));
      _invalid();
    } else if (character == 91) {
      position++;
      if (_take(93)) return;
      do {
        _value(depth + 1);
        if (_take(93)) return;
      } while (_take(44));
      _invalid();
    } else if (character == 34) {
      _string();
    } else {
      final start = position;
      while (position < source.length &&
          !const {
            9,
            10,
            13,
            32,
            44,
            93,
            125,
          }.contains(source.codeUnitAt(position))) {
        position++;
      }
      if (position == start) _invalid();
    }
  }
}

bool _validPackageName(String name, String tag) {
  final version = tag.replaceFirst(RegExp(r'^[vV]'), '');
  for (final package in UpdatePackage.values) {
    if (package == UpdatePackage.unsupported) continue;
    final arches = package == UpdatePackage.androidApk
        ? const ['arm64-v8a', 'armeabi-v7a', 'x86_64']
        : package == UpdatePackage.macosDmg
        ? const ['arm64', 'x64']
        : package == UpdatePackage.windowsInstaller ||
              package == UpdatePackage.windowsPortable
        ? const ['arm64', 'x64']
        : const ['arm64', 'x64', 'x64-v1', 'x64-v2', 'x64-v3'];
    for (final arch in arches) {
      if (name == 'ZolNit-$version${UpdateTarget(package, arch).assetSuffix}') {
        return true;
      }
    }
  }
  return false;
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
            asset.name == 'ZolNit-$version$suffix' &&
            Uri.parse(asset.url).pathSegments[2] == release.tag,
      )
      .toList();
  return assets.length == 1
      ? AppUpdatePlan(target: target, asset: assets.single)
      : null;
}

Uri browserDownloadUri(AppUpdatePlan? plan, {ReleaseManifest? release}) =>
    plan == null
    ? release?.releaseUri ?? Uri.parse(websiteReleasePageUrl)
    : Uri.parse(plan.asset.url);

Future<String> sha256OfFile(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}
