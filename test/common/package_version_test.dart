import 'package:fl_clash/common/package.dart';
import 'package:test/test.dart';

void main() {
  test('orders SemVer prereleases numerically before a stable release', () {
    const ordered = [
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
    ];
    for (var index = 1; index < ordered.length; index++) {
      expect(compareVersions(ordered[index - 1], ordered[index]), lessThan(0));
    }
    expect(compareVersions('v0.9.0-pre.10', '0.9.0-pre.2'), greaterThan(0));
    expect(compareVersions('0.9.0+1', '0.9.0-pre.99+999'), greaterThan(0));
  });

  test('retains abbreviated versions and numeric build tie breaking', () {
    expect(compareVersions('v1', '1.0.0'), 0);
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(compareVersions('1.0.0+2', '1.0.0+10'), lessThan(0));
    expect(compareVersions('1.0.0+build.2', '1.0.0+other'), 0);
    expect(
      compareVersions('1.0.0-99999999999999999999999999', '1.0.0-2'),
      greaterThan(0),
    );
  });

  test(
    'rejects malformed versions and empty or zero-prefixed prerelease identifiers',
    () {
      for (final version in [
        'latest',
        '1.0.0-',
        '1.0.0-a..b',
        '1.0.0-01',
        '1.0.0+',
        '01.0.0',
      ]) {
        expect(
          () => compareVersions(version, '1.0.0'),
          throwsFormatException,
          reason: version,
        );
      }
    },
  );
}
