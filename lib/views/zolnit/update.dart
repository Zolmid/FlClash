import 'dart:async';

import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_update_status.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/package.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'kit.dart';
import 'motion.dart';
import 'skin.dart';

final zolnitDownloadsPage = Uri.parse(websiteDownloadsPageUrl);

enum ZolnitUpdateKind {
  readyOnRestart,
  readyToInstall,
  installing,
  available,
  manual,
}

typedef ZolnitUpdateNotice = ({ZolnitUpdateKind kind, String version});

/// What the product says about [status], or null when it says nothing: an
/// idle, checking or staging updater, and a release that is not newer than
/// [currentVersion], stay silent so an ordinary launch shows no update UI.
ZolnitUpdateNotice? zolnitUpdateNoticeOf(
  AppUpdateStatus status, {
  required String? currentVersion,
}) {
  final release = status.release;
  if (release == null) return null;
  final version = release.tag.replaceFirst(RegExp(r'^[vV]'), '');
  final newer =
      currentVersion != null &&
      compareVersions(release.tag, currentVersion) > 0;
  final kind = switch ((status.phase, status.applyMode)) {
    (AppUpdatePhase.staged, AppUpdateApplyMode.onRestart) =>
      ZolnitUpdateKind.readyOnRestart,
    (AppUpdatePhase.staged, AppUpdateApplyMode.userAction) =>
      ZolnitUpdateKind.readyToInstall,
    (AppUpdatePhase.applying, AppUpdateApplyMode.userAction) =>
      ZolnitUpdateKind.installing,
    (AppUpdatePhase.staged || AppUpdatePhase.announcement, _) when newer =>
      ZolnitUpdateKind.available,
    (AppUpdatePhase.failed, _) when newer => ZolnitUpdateKind.manual,
    _ => null,
  };
  return kind == null ? null : (kind: kind, version: version);
}

String? _runningVersion() {
  try {
    return globalState.packageInfo.version;
  } on Error {
    return null;
  }
}

Future<bool> confirmUpdateInstallation(
  BuildContext context,
  Future<bool> Function() permissionProbe,
) async {
  var allowed = false;
  try {
    allowed = await permissionProbe();
  } catch (_) {}
  if (allowed) return true;
  if (!context.mounted) return false;
  final text = context.appLocalizations;
  return await showZolnitDialog<bool>(
        context,
        (_) => ZolnitAlert(
          title: text.updatePermissionTitle,
          message: text.updatePermissionPrompt,
          cancelLabel: text.updateInstallLater,
          confirmLabel: text.updateGoAuthorize,
        ),
      ) ==
      true;
}

/// The update status as a compact brand row, in place on the page rather than
/// as a modal, and gone whenever there is nothing the user can act on.
class ZolnitUpdateBanner extends ConsumerStatefulWidget {
  const ZolnitUpdateBanner({
    super.key,
    this.padding = EdgeInsets.zero,
    this.dismissible = true,
    this.currentVersion,
  });

  final EdgeInsetsGeometry padding;
  final bool dismissible;
  final String? currentVersion;

  @override
  ConsumerState<ZolnitUpdateBanner> createState() => _ZolnitUpdateBannerState();
}

class _ZolnitUpdateBannerState extends ConsumerState<ZolnitUpdateBanner> {
  String? _dismissed;
  bool _installing = false;

  Future<void> _install() async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      final android = app;
      if (android != null &&
          !await confirmUpdateInstallation(context, android.canInstallApk)) {
        return;
      }
      if (!mounted) return;
      await ref.read(commonActionProvider.notifier).applyStagedAppUpdate();
    } catch (_) {
      // The updater reports the failure through its status.
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = zolnitUpdateNoticeOf(
      ref.watch(appUpdateStatusProvider),
      currentVersion: widget.currentVersion ?? _runningVersion(),
    );
    final key = notice == null ? null : '${notice.kind.name}:${notice.version}';
    final shown = notice != null && key != _dismissed;
    return AnimatedSize(
      duration: context.motionDuration(zolnitStandard),
      curve: zolnitEase,
      alignment: Alignment.topCenter,
      child: ZolnitSwitcher(
        switchKey: shown ? key! : '',
        duration: zolnitQuick,
        child: shown
            ? Padding(
                padding: widget.padding,
                child: _UpdateCard(
                  notice: notice,
                  busy: _installing,
                  failure: ref.watch(appUpdateStatusProvider).failure,
                  onInstall: _install,
                  onDismiss: widget.dismissible
                      ? () => setState(() => _dismissed = key)
                      : null,
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.notice,
    required this.busy,
    required this.onInstall,
    required this.failure,
    required this.onDismiss,
  });

  final ZolnitUpdateNotice notice;
  final bool busy;
  final Object? failure;
  final VoidCallback onInstall;
  final VoidCallback? onDismiss;

  Future<void> _openDownload(BuildContext context) async {
    for (final mode in [
      LaunchMode.inAppBrowserView,
      LaunchMode.externalApplication,
    ]) {
      try {
        if (await supportsLaunchMode(mode) &&
            await launchUrl(zolnitDownloadsPage, mode: mode)) {
          return;
        }
      } catch (_) {}
    }
    if (!context.mounted) return;
    await showZolnitDialog<void>(
      context,
      (dialog) => AlertDialog(
        title: Text(dialog.appLocalizations.goDownload),
        content: SelectableText(zolnitDownloadsPage.toString()),
        actions: [
          TextButton(
            onPressed: () => zolnitCloseDialog(dialog),
            child: Text(dialog.appLocalizations.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appLocalizations;
    final colors = ZolnitColors.of(context);
    final skin = ZolnitSkin.of(context);
    final message = switch (notice.kind) {
      ZolnitUpdateKind.readyOnRestart => text.zolnitUpdateReadyRestart,
      ZolnitUpdateKind.readyToInstall => switch (failure) {
        MessageException(:final message) => message,
        null => text.zolnitUpdateReadyInstall(notice.version),
        _ => text.updateInstallFailed,
      },
      ZolnitUpdateKind.installing => text.zolnitUpdateInstalling,
      ZolnitUpdateKind.available => text.zolnitUpdateAvailable(notice.version),
      ZolnitUpdateKind.manual => text.zolnitUpdateManual(notice.version),
    };
    final action = switch (notice.kind) {
      ZolnitUpdateKind.readyToInstall => Wrap(
        spacing: 8,
        children: [
          ZolnitButton(
            key: const ValueKey('zolnit-update-install'),
            label: text.zolnitUpdateInstall,
            primary: true,
            onPressed: busy ? null : onInstall,
          ),
          ZolnitButton(
            key: const ValueKey('zolnit-update-download'),
            label: text.goDownload,
            onPressed: () => unawaited(_openDownload(context)),
          ),
        ],
      ),
      ZolnitUpdateKind.available || ZolnitUpdateKind.manual => ZolnitButton(
        key: const ValueKey('zolnit-update-download'),
        label: text.goDownload,
        onPressed: () => unawaited(_openDownload(context)),
      ),
      _ => null,
    };
    final dismiss =
        onDismiss == null || notice.kind == ZolnitUpdateKind.installing
        ? null
        : IconButton(
            tooltip: text.close,
            onPressed: onDismiss,
            icon: GlyphIcon(AppGlyphs.close, size: 16, color: colors.muted),
          );
    final label = Text(
      message,
      style: zolnitText(context, 13, leading: 19, weight: FontWeight.w500),
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: ZolnitCard(
        key: const ValueKey('zolnit-update-banner'),
        color: colors.blue,
        bordered: false,
        corner: skin.tileCorner,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = action != null && constraints.maxWidth < 460;
            final lead = ZolnitIconTile(
              glyph: notice.kind == ZolnitUpdateKind.installing
                  ? AppGlyphs.refresh
                  : AppGlyphs.sparkle,
              tint: colors.solid,
              size: 32,
              iconSize: 16,
              color: colors.accent,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      lead,
                      const SizedBox(width: 12),
                      Expanded(child: label),
                      ?dismiss,
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 44,
                      top: 6,
                      end: 8,
                    ),
                    child: action,
                  ),
                ],
              );
            }
            return Row(
              children: [
                lead,
                const SizedBox(width: 12),
                Expanded(child: label),
                if (action != null) ...[const SizedBox(width: 12), action],
                if (dismiss != null) dismiss else const SizedBox(width: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
