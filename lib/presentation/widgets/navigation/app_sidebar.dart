/// Sellio Metrics — App Sidebar Navigation
///
/// Desktop sidebar using HuxSidebar with Sellio branding.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final items = [
      HuxSidebarItemData(
        id: 'analytics',
        icon: LucideIcons.barChart3,
        label: l10n.navAnalytics,
      ),
      HuxSidebarItemData(
        id: 'open_prs',
        icon: LucideIcons.gitPullRequest,
        label: l10n.navOpenPrs,
      ),
      HuxSidebarItemData(
        id: 'team',
        icon: LucideIcons.users,
        label: l10n.navTeam,
      ),
      HuxSidebarItemData(
        id: 'charts',
        icon: LucideIcons.pieChart,
        label: l10n.navCharts,
      ),
      HuxSidebarItemData(
        id: 'about',
        icon: LucideIcons.info,
        label: l10n.navAbout,
      ),
      HuxSidebarItemData(
        id: 'settings',
        icon: LucideIcons.settings,
        label: l10n.navSettings,
      ),
    ];

    final ids = items.map((i) => i.id).toList();

    return HuxSidebar(
      items: items,
      selectedItemId: ids[selectedIndex],
      onItemSelected: (id) {
        final index = ids.indexOf(id);
        if (index >= 0) onItemSelected(index);
      },
      header: _buildHeader(context),
      footer: _buildFooter(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: SellioColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sellio',
                style: AppTypography.subtitle.copyWith(
                  color: context.isDark ? Colors.white : SellioColors.gray700,
                ),
              ),
              Text(
                'Squad Dashboard',
                style: AppTypography.caption.copyWith(
                  color: SellioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return Column(
      children: [
        Divider(
          color: context.isDark
              ? Colors.white10
              : SellioColors.gray300,
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              settings.isDarkMode ? LucideIcons.moon : LucideIcons.sun,
              size: 18,
              color: SellioColors.textSecondary,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                settings.isDarkMode ? 'Dark' : 'Light',
                style: AppTypography.caption.copyWith(
                  color: SellioColors.textSecondary,
                ),
              ),
            ),
            HuxSwitch(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleTheme(),
            ),
          ],
        ),
      ],
    );
  }
}
