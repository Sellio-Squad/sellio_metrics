/// Sellio Metrics — Settings Page
///
/// Configuration panel for theme, locale, and repository selection.
/// Delegates each setting section to focused sub-widgets.
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import 'settings_section.dart';
import 'repository_selector.dart';
import 'theme_toggle.dart';
import 'language_toggle.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return SingleChildScrollView(
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
            children: const [RepositorySelector()],
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
    );
  }
}
