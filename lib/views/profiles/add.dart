import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/custom/custom.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _editorOpenPause = Duration(milliseconds: 150);

void showAddProfilePage(BuildContext origin) {
  final context = globalState.navigatorKey.currentState!.context;
  showExtend(
    context,
    builder: (context) => CommonScaffold(
      title: context.appLocalizations.addProfile,
      body: AddProfileView(context: context, origin: origin),
    ),
  );
}

class AddProfileView extends ConsumerWidget {
  final BuildContext context;

  /// Where a page the add page leads to opens: the desktop sheet is on the root.
  final BuildContext origin;

  const AddProfileView({
    super.key,
    required this.context,
    required this.origin,
  });

  Future<void> _handleAddProfileFormFile(WidgetRef ref) async {
    unawaited(ref.read(profilesActionProvider.notifier).addProfileFormFile());
  }

  Future<void> _toScan(WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    if (system.isDesktop) {
      unawaited(profilesAction.addProfileFormQrCode());
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(profilesAction.addProfileFromLink(url));
      });
    }
  }

  Future<void> _toAdd(WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final appLocalizations = context.appLocalizations;
    final res = await dialogs.showNamedUrlsInput(
      title: appLocalizations.importFromLink,
      urlLabel: appLocalizations.link,
      batchTip: appLocalizations.batchLinkInputTip,
      urlValidator: (value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.link);
        }
        if (!value.isUrl && !value.isShareLink) {
          return appLocalizations.invalidLinkTip;
        }
        return null;
      },
      existingUrls: {
        for (final profile in ref.read(profilesProvider))
          if (profile.url.isNotEmpty) profile.url,
      },
      withAgeSecretKey: true,
    );
    switch (res) {
      case null:
        return;
      case [final single]:
        unawaited(
          profilesAction.addProfileFromLink(
            single.url,
            label: single.label,
            ageSecretKey: single.ageSecretKey,
          ),
        );
      default:
        unawaited(
          profilesAction.addProfilesFromLinks([
            for (final item in res) item.url,
          ]),
        );
    }
  }

  Future<void> _toAddCustom(BuildContext context, WidgetRef ref) async {
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final label = context.appLocalizations.unnamed;
    Widget editor() => CustomProfileView(
      profileId: profilesAction.addCustomProfile(label),
      isNew: true,
    );
    await _openEditor(context, editor);
  }

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final core = ref.read(coreHandlerProvider);
    final name = await dialogs.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.newProfile,
        value: '',
        labelText: appLocalizations.name,
        autofocus: true,
        keyboardType: TextInputType.text,
        inputFormatters: TextInputLimits.limit(TextInputLimits.name),
        validator: (value) => value == null || value.trim().isEmpty
            ? appLocalizations.profileNameNullValidationDesc
            : null,
      ),
    );
    if (name == null || !context.mounted) return;
    final profile = Profile.normal(label: name.trim());
    var saving = false;

    Future<void> save(BuildContext editorContext, String content) async {
      if (saving) return;
      saving = true;
      try {
        final saved = await globalState.safeRun(
          () => profile.saveFile(
            utf8.encode(content),
            validate: (path, _) => core.validateConfig(path),
          ),
          title: appLocalizations.newProfile,
        );
        if (saved == null) return;
        profilesAction.putProfile(saved);
        if (editorContext.mounted) {
          Navigator.of(editorContext).pop();
        }
      } finally {
        saving = false;
      }
    }

    await _openEditor(
      context,
      () => EditorPage(
        title: profile.label,
        content: '',
        onSave: (context, _, content) => save(context, content),
        onPop: (context, _, content) async {
          if (saving) return false;
          if (content.isEmpty) return true;
          final result = await dialogs.showMessage(
            title: profile.label,
            message: TextSpan(text: appLocalizations.hasCacheChange),
          );
          if (result == false) return true;
          if (result == true && context.mounted) {
            await save(context, content);
          }
          return false;
        },
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    Widget Function() editor,
  ) async {
    final navigator = Navigator.of(context);
    if (!origin.mounted || Navigator.of(origin) == navigator) {
      unawaited(BaseNavigator.pushReplacement(context, editor()));
      return;
    }
    // The sheet sits above origin's navigator: a page opened there before the
    // sheet has gone fades in beneath it.
    navigator.pop();
    await whenRouteSettled(context);
    await Future<void>.delayed(_editorOpenPause);
    if (origin.mounted) {
      unawaited(BaseNavigator.push(origin, editor()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 16),
      children: [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.qrCode),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: () => _toScan(ref),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.add),
          title: Text(appLocalizations.newProfile),
          subtitle: Text(appLocalizations.newProfileDesc),
          onTap: () => _createProfile(context, ref),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.importFile),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: () => _handleAddProfileFormFile(ref),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.cloudDownload),
          title: Text(appLocalizations.link),
          subtitle: Text(appLocalizations.linkDesc),
          onTap: () => _toAdd(ref),
        ),
        ListItem(
          leading: const GlyphIcon(AppGlyphs.customize),
          title: Text(appLocalizations.customProfile),
          subtitle: Text(appLocalizations.customProfileDesc),
          onTap: () => _toAddCustom(context, ref),
        ),
      ],
    );
  }
}
