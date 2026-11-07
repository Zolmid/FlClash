import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/changelog.dart';

import 'common.dart';

const releaseChangelogJsonMarker = '<!-- flclash:changelog:json';

const _releaseChangelogJsonEndMarker = '-->';

String changelogGroupTitle(
  AppLocalizations appLocalizations,
  ChangelogType type,
) => switch (type) {
  ChangelogType.breaking => appLocalizations.changelogBreaking,
  ChangelogType.feat => appLocalizations.changelogFeatures,
  ChangelogType.fix => appLocalizations.changelogFixes,
  ChangelogType.perf => appLocalizations.changelogPerformance,
  ChangelogType.revert => appLocalizations.changelogReverts,
  ChangelogType.unknown => '',
};

ChangelogVersion? parseReleaseChangelog(String? body) {
  if (body == null) {
    return null;
  }
  final begin = body.indexOf(releaseChangelogJsonMarker);
  if (begin < 0) {
    return null;
  }
  final start = begin + releaseChangelogJsonMarker.length;
  final end = body.indexOf(_releaseChangelogJsonEndMarker, start);
  if (end < 0) {
    return null;
  }
  try {
    final changelog = Changelog.fromJson(
      jsonDecode(body.substring(start, end)) as Map<String, dynamic>,
    );
    if (!changelog.isSupported) {
      commonPrint.log(
        'changelog schema ${changelog.schemaVersion} is not supported',
        logLevel: LogLevel.warning,
      );
      return null;
    }
    return changelog.versions.firstOrNull;
  } catch (error) {
    commonPrint.log(
      'changelog decode failed ${compactError(error)}',
      logLevel: LogLevel.warning,
    );
    return null;
  }
}

/// Removes internal release metadata before displaying a notice.
String displayReleaseNotes(String body) {
  final metadata = body.indexOf(releaseChangelogJsonMarker);
  if (metadata >= 0) body = body.substring(0, metadata);
  final out = StringBuffer();
  var cursor = 0;
  while (cursor < body.length) {
    final start = body.indexOf('<!--', cursor);
    if (start < 0) {
      out.write(body.substring(cursor));
      break;
    }
    out.write(body.substring(cursor, start));
    final end = body.indexOf('-->', start + 4);
    if (end < 0) break;
    cursor = end + 3;
  }
  return out.toString().trim();
}
