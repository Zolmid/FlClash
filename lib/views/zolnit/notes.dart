import 'package:fl_clash/common/changelog.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/models/changelog.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';

String releaseNotesPlainText(String body) => displayReleaseNotes(body)
    .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
    .replaceAll('**', '')
    .trim();

TextSpan releaseNotesMarkdownSpan(BuildContext context, String body) {
  final lines = displayReleaseNotes(body).split('\n');
  return TextSpan(
    style: AppTextStyle.subheadline.of(context),
    children: [for (final line in lines) ..._lineSpans(context, line)],
  );
}

List<TextSpan> _lineSpans(BuildContext context, String line) {
  const heading = r'^\s{0,3}#{1,6}\s+';
  final isHeading = RegExp(heading).hasMatch(line);
  final rawValue = line
      .replaceFirst(RegExp(heading), '')
      .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ');
  final group = switch (rawValue.trim().toLowerCase()) {
    'features' => ChangelogType.feat,
    'bug fixes' || 'fixes' => ChangelogType.fix,
    'breaking changes' => ChangelogType.breaking,
    'performance' => ChangelogType.perf,
    'reverts' => ChangelogType.revert,
    _ => null,
  };
  final value = isHeading && group != null
      ? changelogGroupTitle(context.appLocalizations, group)
      : rawValue;
  final result = <TextSpan>[];
  var cursor = 0;
  for (final match in RegExp(r'\*\*(.+?)\*\*').allMatches(value)) {
    result.add(TextSpan(text: value.substring(cursor, match.start)));
    result.add(
      TextSpan(
        text: match.group(1),
        style: AppTextStyle.subheadline.of(context, emphasized: true),
      ),
    );
    cursor = match.end;
  }
  result.add(TextSpan(text: '${value.substring(cursor)}\n'));
  return [
    TextSpan(
      style: isHeading
          ? AppTextStyle.subheadline.of(context, emphasized: true)
          : null,
      children: result,
    ),
  ];
}

class ReleaseNotesContent extends StatefulWidget {
  const ReleaseNotesContent({super.key, this.body, this.span, this.heading})
    : assert(body != null || span != null);

  final String? body;
  final TextSpan? span;
  final String? heading;

  @override
  State<ReleaseNotesContent> createState() => _ReleaseNotesContentState();
}

class _ReleaseNotesContentState extends State<ReleaseNotesContent> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final span = widget.span ?? releaseNotesMarkdownSpan(context, widget.body!);
    final plain = span.toPlainText();
    final long = plain.length > 600 || '\n'.allMatches(plain).length > 10;
    final details = !long || expanded
        ? SelectableText.rich(span)
        : const SizedBox(width: double.infinity);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.heading != null)
          Text(widget.heading!, style: AppTextStyle.title2.of(context)),
        if (context.disableAnimations)
          details
        else
          AnimatedSize(
            duration: context.motionDuration(zolnitStandard),
            curve: zolnitEase,
            alignment: Alignment.topCenter,
            child: details,
          ),
        if (long)
          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(
              expanded
                  ? context.appLocalizations.showLess
                  : context.appLocalizations.showMore,
            ),
          ),
      ],
    );
  }
}
