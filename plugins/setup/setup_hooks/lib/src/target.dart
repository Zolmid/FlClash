import 'error.dart';

const _goAmd64Levels = ['v1', 'v2', 'v3'];

class Target {
  const Target({
    required this.goos,
    required this.goarch,
    this.lowMemory = false,
    this.goamd64,
  });

  final String goos;
  final String goarch;
  final bool lowMemory;
  final String? goamd64;

  static const iosArm64 = Target(goos: 'ios', goarch: 'arm64');
  static const iosArm64LowMem = Target(
    goos: 'ios',
    goarch: 'arm64',
    lowMemory: true,
  );

  static const macosArm64 = Target(goos: 'darwin', goarch: 'arm64');
  static const macosAmd64 = Target(goos: 'darwin', goarch: 'amd64');

  static const linuxArm64 = Target(goos: 'linux', goarch: 'arm64');
  static const linuxAmd64 = Target(goos: 'linux', goarch: 'amd64');

  static const windowsAmd64 = Target(goos: 'windows', goarch: 'amd64');
  static const windowsArm64 = Target(goos: 'windows', goarch: 'arm64');

  static const all = [
    iosArm64,
    macosArm64,
    macosAmd64,
    linuxArm64,
    linuxAmd64,
    windowsAmd64,
    windowsArm64,
  ];

  static List<Target> forPlatform(String platform) =>
      all.where((target) => target.platformDir == platform).toList();

  static Target resolve({required String platform, required String goarch}) {
    for (final target in forPlatform(platform)) {
      if (target.goarch == goarch) return target;
    }
    throw BuildException('No $platform Core target for GOARCH $goarch');
  }

  Target withGoAmd64UserDefine(Object? value) {
    if (goarch != 'amd64' || value == null) return this;
    if (value is! String || !_goAmd64Levels.contains(value)) {
      throw BuildException(
        'hooks.user_defines.setup.goamd64 must be ${_goAmd64Levels.join(', ')}',
      );
    }
    return withGoAmd64(value);
  }

  Target withGoAmd64(String level) {
    if (goarch != 'amd64') {
      throw BuildException('GOAMD64 applies to amd64 only: $this');
    }
    if (level == 'v1') {
      if (goamd64 == null) return this;
      return Target(goos: goos, goarch: goarch, lowMemory: lowMemory);
    }
    if (goamd64 == level) return this;
    return Target(
      goos: goos,
      goarch: goarch,
      lowMemory: lowMemory,
      goamd64: level,
    );
  }

  bool get hasHelper => goos == 'linux' || goos == 'windows';

  String get executableExtension => goos == 'windows' ? '.exe' : '';

  String get platformDir => goos == 'darwin' ? 'macos' : goos;

  String get rustTriple {
    final arch = switch (goarch) {
      'amd64' => 'x86_64',
      'arm64' => 'aarch64',
      _ => throw BuildException('No Rust target for $this'),
    };
    return switch (goos) {
      'windows' => '$arch-pc-windows-msvc',
      'linux' => '$arch-unknown-linux-gnu',
      _ => throw BuildException('No Rust target for $this'),
    };
  }

  @override
  String toString() =>
      '$goos/$goarch${lowMemory ? ' (low memory)' : ''}'
      '${goamd64 == null ? '' : ' goamd64=$goamd64'}';
}
