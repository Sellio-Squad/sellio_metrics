
import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/settings_section.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/repository_selector.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/theme_toggle.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/language_toggle.dart';
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.navSettings,
              style: AppTypography.headline.copyWith(color: scheme.title),
            ),
            const SizedBox(height: AppSpacing.xxl),


            // Repository Selection
            SettingsSection(
              title: l10n.settingsRepository,
              icon: Icons.source_outlined,
              children: const [
                RepositorySelector(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Appearance
            SettingsSection(
              title: l10n.settingsTheme,
              icon: Icons.palette_outlined,
              children: const [ThemeToggle()],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Language
            SettingsSection(
              title: l10n.settingsLanguage,
              icon: Icons.translate,
              children: const [LanguageToggle()],
            ),
          ],
        ),
      ),
    );
  }
}
