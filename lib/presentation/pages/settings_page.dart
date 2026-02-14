/// Sellio Metrics — Settings Page
///
/// Configuration panel for theme and locale only.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navSettings,
            style: AppTypography.headline.copyWith(
              color: context.isDark ? Colors.white : SellioColors.gray700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Appearance
          _buildSection(
            context,
            title: l10n.settingsTheme,
            icon: Icons.palette_outlined,
            children: [
              _buildThemeToggle(context, l10n),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Language
          _buildSection(
            context,
            title: l10n.settingsLanguage,
            icon: Icons.translate,
            children: [
              _buildLanguageToggle(context, l10n),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark
            ? SellioColors.darkSurface
            : SellioColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: SellioColors.primaryIndigo),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.subtitle.copyWith(
                  color: context.isDark ? Colors.white : SellioColors.gray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, AppLocalizations l10n) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsTheme,
              style: AppTypography.body.copyWith(
                color: context.isDark
                    ? Colors.white70
                    : SellioColors.textSecondary,
              ),
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

  Widget _buildLanguageToggle(BuildContext context, AppLocalizations l10n) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              settings.locale.languageCode == 'ar' ? 'العربية' : 'English',
              style: AppTypography.body.copyWith(
                color: context.isDark
                    ? Colors.white70
                    : SellioColors.textSecondary,
              ),
            ),
            HuxSwitch(
              value: settings.locale.languageCode == 'ar',
              onChanged: (_) => settings.toggleLocale(),
            ),
          ],
        );
      },
    );
  }
}
