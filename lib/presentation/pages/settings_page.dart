/// Sellio Metrics — Settings Page
///
/// Configuration panel for theme and locale.
/// Follows SRP — each setting section is a separate sub-widget.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

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

          // Appearance
          _SettingsSection(
            title: l10n.settingsTheme,
            icon: Icons.palette_outlined,
            children: [
              const _ThemeToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Language
          _SettingsSection(
            title: l10n.settingsLanguage,
            icon: Icons.translate,
            children: [
              const _LanguageToggle(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable settings section container.
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.subtitle.copyWith(color: scheme.title),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// Theme toggle row.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsTheme,
              style: AppTypography.body.copyWith(color: scheme.body),
            ),
            HuxSwitch(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleTheme(),
            ),
          ],
        );
      },
    );
  }
}

/// Language toggle row.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        final isArabic = settings.locale.languageCode == 'ar';
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? l10n.languageArabic : l10n.languageEnglish,
              style: AppTypography.body.copyWith(color: scheme.body),
            ),
            HuxSwitch(
              value: isArabic,
              onChanged: (_) => settings.toggleLocale(),
            ),
          ],
        );
      },
    );
  }
}
