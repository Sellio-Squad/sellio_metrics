/// Sellio Metrics — Settings Page
///
/// Configuration panel for thresholds, theme, and notifications.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../providers/dashboard_provider.dart';
import '../providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.navSettings,
            style: AppTypography.headline.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1a1a2e),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Theme Settings
          _buildSection(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            isDark: isDark,
            children: [
              _buildThemeToggle(context, isDark),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Bottleneck Settings
          _buildSection(
            context,
            title: 'Bottleneck Analysis',
            icon: Icons.warning_amber_outlined,
            isDark: isDark,
            children: [
              _buildThresholdSlider(context, isDark),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // About Section
          _buildSection(
            context,
            title: 'About',
            icon: Icons.info_outline,
            isDark: isDark,
            children: [
              _buildInfoRow('Version', '3.0.0', isDark),
              _buildInfoRow('UI Framework', 'Hux v0.25.0', isDark),
              _buildInfoRow('Built with', 'Flutter Web', isDark),
              _buildInfoRow('Data Source', 'pr_metrics.json (CI Bot)', isDark),
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
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE5E7EB),
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
                  color: isDark ? Colors.white : const Color(0xFF1a1a2e),
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

  Widget _buildThemeToggle(BuildContext context, bool isDark) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.settingsTheme,
              style: AppTypography.body.copyWith(
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            HuxSwitch(
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThresholdSlider(BuildContext context, bool isDark) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.settingsThreshold,
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: SellioColors.primaryIndigo.withValues(alpha: 0.1),
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

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1a1a2e),
            ),
          ),
        ],
      ),
    );
  }
}
