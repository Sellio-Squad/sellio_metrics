/// Sellio Metrics — Settings Page
///
/// Configuration panel for thresholds, theme, locale, and about info.
/// Uses AppSettingsProvider instead of ThemeProvider, localized strings.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
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
          const SizedBox(height: AppSpacing.xl),

          // Bottleneck Analysis
          _buildSection(
            context,
            title: l10n.settingsThreshold,
            icon: Icons.warning_amber_outlined,
            children: [
              _buildThresholdSlider(context, l10n),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // About
          _buildSection(
            context,
            title: l10n.navAbout,
            icon: Icons.info_outline,
            children: [
              _buildInfoRow(context, 'Version', '3.0.0'),
              _buildInfoRow(context, 'UI Framework', 'Hux v0.25.0'),
              _buildInfoRow(context, 'Built with', 'Flutter Web'),
              _buildInfoRow(context, 'Data Source', 'pr_metrics.json (CI Bot)'),
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

  Widget _buildThresholdSlider(BuildContext context, AppLocalizations l10n) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.settingsThreshold,
                  style: AppTypography.body.copyWith(
                    color: context.isDark
                        ? Colors.white70
                        : SellioColors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: SellioColors.primaryIndigo.withAlpha(25),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    '${provider.bottleneckThreshold.round()}h',
                    style: AppTypography.caption.copyWith(
                      color: SellioColors.primaryIndigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            HuxSlider(
              value: provider.bottleneckThreshold,
              min: 12,
              max: 168,
              onChanged: (v) => provider.setBottleneckThreshold(v),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: context.isDark
                  ? Colors.white54
                  : SellioColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: context.isDark ? Colors.white : SellioColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}
