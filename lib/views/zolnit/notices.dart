import 'dart:async';
import 'package:fl_clash/common/context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zolnit_client/zolnit_client.dart';

import '../../providers/zolnit_realtime.dart';

import 'data.dart';
import 'kit.dart';
import 'motion.dart';

Future<void> showZolnitNotice(BuildContext context, ZolnitNotice notice) {
  final text = context.appLocalizations;
  return showZolnitDialog<void>(
    context,
    (_) => ZolnitAlert(
      title: notice.title,
      message: notice.body.isEmpty ? '—' : notice.body,
      confirmLabel: text.zolnitGotIt,
    ),
  );
}

Future<void> showZolnitNotices(
  BuildContext context,
  List<ZolnitNotice> notices,
  List<ZolnitRealtimeInboxItem> inbox, {
  required ZolnitSessionController session,
  required bool Function() isCurrent,
  required Future<bool> Function(ZolnitRealtimeInboxItem) onOpen,
  Listenable? invalidation,
}) {
  final text = context.appLocalizations;
  final read = {
    for (final item in inbox)
      if (item.read) item.id,
  };
  Future<void> dialog(BuildContext ctx, WidgetBuilder builder) async {
    if (!isCurrent()) return;
    final route = zolnitDialogRoute<void>(ctx, builder);
    void guard() {
      if (!isCurrent()) {
        scheduleMicrotask(() {
          if (route.isActive) route.navigator?.removeRoute(route);
        });
      }
    }

    session.addListener(guard);
    invalidation?.addListener(guard);
    try {
      await Navigator.of(ctx, rootNavigator: true).push(route);
    } finally {
      session.removeListener(guard);
      invalidation?.removeListener(guard);
    }
  }

  final visible = notices
      .where(
        (n) =>
            !inbox.any((item) => item.title == n.title && item.body == n.body),
      )
      .toList();
  return dialog(
    context,
    (outer) => StatefulBuilder(
      builder: (outer, redraw) => AlertDialog(
        title: Text(text.zolnitNotices),
        content: SizedBox(
          width: 420,
          child: visible.isEmpty && inbox.isEmpty
              ? Text(text.zolnitNoNotices)
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in inbox)
                      ListTile(
                        title: Text(
                          item.title,
                          style: zolnitText(
                            outer,
                            14,
                            weight: read.contains(item.id)
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          if (!isCurrent()) return;
                          if (!read.contains(item.id)) {
                            unawaited(
                              onOpen(item).then((ok) {
                                if (ok && outer.mounted && isCurrent()) {
                                  redraw(() => read.add(item.id));
                                }
                              }),
                            );
                          }
                          unawaited(
                            dialog(
                              outer,
                              (inner) => AlertDialog(
                                title: Text(item.title),
                                content: SingleChildScrollView(
                                  child: Text(item.body),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        zolnitCloseDialog<void>(inner),
                                    child: Text(text.zolnitGotIt),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    for (final n in visible)
                      ListTile(
                        title: Text(n.title),
                        subtitle: n.createdAt == null
                            ? null
                            : Text(zolnitDotDate(n.createdAt!)),
                        onTap: () => dialog(
                          outer,
                          (inner) => AlertDialog(
                            title: Text(n.title),
                            content: SingleChildScrollView(child: Text(n.body)),
                            actions: [
                              TextButton(
                                onPressed: () => zolnitCloseDialog<void>(inner),
                                child: Text(text.zolnitGotIt),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => zolnitCloseDialog<void>(outer),
            child: Text(text.close),
          ),
        ],
      ),
    ),
  );
}
