import 'dart:math';

import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/common/shape.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonDialog extends ConsumerWidget {
  final String title;
  final double maxWidth;
  final Widget? trailing;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;

  const CommonDialog({
    super.key,
    required this.title,
    this.maxWidth = 300,
    this.trailing,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
  });

  FocusScopeNode? _inputFocusScope(BuildContext dialogContext) {
    final node = FocusManager.instance.primaryFocus;
    final focusContext = node?.context;
    if (focusContext == null) return null;
    var isInsideDialog = false;
    focusContext.visitAncestorElements((element) {
      if (element.widget is! CommonDialog) return true;
      isInsideDialog = identical(element, dialogContext);
      return false;
    });
    if (!isInsideDialog) return null;
    final isInput =
        focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.widget is Slider ||
        focusContext.findAncestorWidgetOfExactType<Slider>() != null;
    return isInput ? node?.enclosingScope : null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(viewSizeProvider);
    final isTV = ref.watch(tvLayoutProvider);
    return ListenableBuilder(
      listenable: FocusManager.instance,
      builder: (backContext, child) => PopScope(
        canPop: !isTV || _inputFocusScope(context) == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop &&
              isTV &&
              ModalRoute.of(backContext)?.isCurrent == true) {
            _inputFocusScope(context)?.requestScopeFocus();
          }
        },
        child: child!,
      ),
      child: AlertDialog(
        title: trailing == null
            ? Text(title)
            : Row(
                children: [
                  Expanded(child: Text(title)),
                  trailing!,
                ],
              ),
        actions: actions,
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        contentPadding: padding,
        backgroundColor: backgroundColor,
        content: Container(
          constraints: BoxConstraints(
            maxHeight: min(size.height - 40, 500),
            maxWidth: maxWidth,
          ),
          width: size.width - 40,
          child: !overrideScroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }
}

class CommonModal extends ConsumerWidget {
  final Widget? child;

  const CommonModal({super.key, this.child});

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    return Center(
      child: Container(
        width: size.width * 0.85,
        height: size.height * 0.85,
        decoration: const ShapeDecoration(shape: AppShape.xxl),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
