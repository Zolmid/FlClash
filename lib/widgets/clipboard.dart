import 'package:fl_clash/common/common.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  context.showNotifier(context.appLocalizations.copySuccess);
}
