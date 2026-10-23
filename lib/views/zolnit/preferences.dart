import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'kit.dart';
import 'skin.dart';

class ZolnitPreferencesPage extends ConsumerWidget {
  const ZolnitPreferencesPage({
    super.key,
    required this.openWebsite,
    this.compact = false,
  });

  final VoidCallback openWebsite;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.appLocalizations;
    final skin = ZolnitSkin.of(context);
    final colors = ZolnitColors.of(context);
    return ListView(
      key: const ValueKey('zolnit-preferences-page'),
      padding: zolnitPagePadding(skin, compact: compact),
      children: [
        ZolnitPageHeading(
          title: text.zolnitPreferencesHeadline,
          subtitle: text.zolnitPreferencesSubtitle,
        ),
        const SizedBox(height: 24),
        ZolnitCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: generateSection(
            footer: [
              if (skin.desktop) text.zolnitStartOnBootHint,
              text.zolnitConnectOnLaunchHint,
            ].join('\n'),
            items: [
              if (skin.desktop)
                ConfigToggleItem(
                  key: const ValueKey('zolnit-auto-launch'),
                  selector: appSettingProvider.select((s) => s.autoLaunch),
                  title: (l) => l.zolnitStartOnBoot,
                  leading: const GlyphIcon(AppGlyphs.power),
                  onChanged: (ref, value) => ref
                      .read(appSettingProvider.notifier)
                      .update((s) => s.copyWith(autoLaunch: value)),
                ),
              ConfigToggleItem(
                key: const ValueKey('zolnit-auto-connect'),
                selector: appSettingProvider.select((s) => s.autoRun),
                title: (l) => l.zolnitConnectOnLaunch,
                leading: const GlyphIcon(AppGlyphs.proxies),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((s) => s.copyWith(autoRun: value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ZolnitCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: generateSection(
            items: [
              ConfigOptionsItem<ThemeMode>(
                selector: themeSettingProvider.select((s) => s.themeMode),
                title: (l) => l.themeMode,
                leading: const GlyphIcon(AppGlyphs.sun),
                options: ThemeMode.values,
                textBuilder: (mode) => switch (mode) {
                  ThemeMode.system => text.auto,
                  ThemeMode.light => text.light,
                  ThemeMode.dark => text.dark,
                },
                onChanged: (ref, value) => ref
                    .read(themeSettingProvider.notifier)
                    .update((s) => s.copyWith(themeMode: value)),
              ),
              ListItem<Locale?>.options(
                leading: const GlyphIcon(AppGlyphs.language),
                title: Text(text.language),
                value: getLocaleForString(
                  ref.watch(appSettingProvider.select((s) => s.locale)),
                ),
                options: [null, ...AppLocalizations.delegate.supportedLocales],
                textBuilder: (locale) => locale?.label ?? text.defaultText,
                onChanged: (locale) => ref
                    .read(appSettingProvider.notifier)
                    .update((s) => s.copyWith(locale: locale?.toString())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ZolnitCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: generateSection(
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: Text(text.about),
                subtitle: const Text('ZolNit'),
                trailing: const GlyphIcon(AppGlyphs.chevronForward),
                onTap: openWebsite,
              ),
            ],
          ),
        ),
        if (ref.watch(safeModeProvider)) ...[
          const SizedBox(height: 20),
          Text(
            text.zolnitPreferencesSafeHint,
            style: zolnitText(context, 12, color: colors.muted),
          ),
        ],
      ],
    );
  }
}
