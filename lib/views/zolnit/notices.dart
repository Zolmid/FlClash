import 'package:fl_clash/common/context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import 'data.dart';

Future<void> showZolnitNotice(BuildContext context, ZolnitNotice notice) {
  final text = context.appLocalizations;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(notice.title),
      content: SingleChildScrollView(
        child: Text(notice.body.isEmpty ? '—' : notice.body),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.confirm),
        ),
      ],
    ),
  );
}

Future<void> showZolnitNotices(
  BuildContext context,
  List<ZolnitNotice> notices,
) {
  final text = context.appLocalizations;
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(text.zolnitNotices),
      content: SizedBox(
        width: 420,
        child: notices.isEmpty
            ? Text(text.zolnitNoNotices)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final notice in notices)
                    ListTile(
                      title: Text(notice.title),
                      subtitle: notice.createdAt == null
                          ? null
                          : Text(zolnitDotDate(notice.createdAt!)),
                      onTap: () => showZolnitNotice(dialog, notice),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(text.confirm),
        ),
      ],
    ),
  );
}
