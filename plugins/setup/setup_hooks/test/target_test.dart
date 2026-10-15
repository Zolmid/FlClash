import 'package:setup_hooks/src/error.dart';
import 'package:setup_hooks/src/target.dart';
import 'package:test/test.dart';

void main() {
  group('resolve', () {
    test('finds the target for a platform and GOARCH', () {
      expect(Target.resolve(platform: 'ios', goarch: 'arm64'), Target.iosArm64);
      expect(
        Target.resolve(platform: 'linux', goarch: 'arm64'),
        Target.linuxArm64,
      );
      expect(
        Target.resolve(platform: 'macos', goarch: 'arm64'),
        Target.macosArm64,
      );
      expect(
        Target.resolve(platform: 'windows', goarch: 'amd64'),
        Target.windowsAmd64,
      );
    });

    test('rejects a GOARCH or platform without a Core', () {
      expect(
        () => Target.resolve(platform: 'linux', goarch: 'riscv64'),
        throwsA(isA<BuildException>()),
      );
      expect(
        () => Target.resolve(platform: 'ios', goarch: 'amd64'),
        throwsA(isA<BuildException>()),
      );
    });
  });

  test('GOAMD64 variants validate levels and preserve target properties', () {
    final v3 = Target.linuxAmd64.withGoAmd64UserDefine('v3');
    expect(v3.goamd64, 'v3');
    expect(v3.platformDir, 'linux');
    expect(v3.withGoAmd64('v1').goamd64, isNull);
    expect(Target.iosArm64.withGoAmd64UserDefine('v3'), Target.iosArm64);
    expect(
      () => Target.linuxAmd64.withGoAmd64UserDefine('v4'),
      throwsA(isA<BuildException>()),
    );
    expect(
      () => Target.linuxAmd64.withGoAmd64UserDefine(3),
      throwsA(isA<BuildException>()),
    );
  });

  test('only Linux and Windows ship the Helper', () {
    expect(Target.all.where((target) => target.hasHelper), [
      Target.linuxArm64,
      Target.linuxAmd64,
      Target.windowsAmd64,
      Target.windowsArm64,
    ]);
  });

  test('names the Rust target triple for Helper platforms', () {
    expect(Target.windowsAmd64.rustTriple, 'x86_64-pc-windows-msvc');
    expect(Target.linuxArm64.rustTriple, 'aarch64-unknown-linux-gnu');
    expect(() => Target.macosArm64.rustTriple, throwsA(isA<BuildException>()));
  });
}
