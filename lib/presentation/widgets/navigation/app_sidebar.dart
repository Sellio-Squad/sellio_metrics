/// Sellio Metrics — App Sidebar Navigation
///
/// Desktop sidebar using design system components with Sellio branding.
/// Follows SRP — header and footer are separate sub-widgets.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/design_system.dart';
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
      header: const _SidebarHeader(),
      footer: const _SidebarFooter(),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: SellioColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(
            child: Text(
              'S',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                style: AppTypography.subtitle.copyWith(color: scheme.title),
              ),
              Text(
                l10n.appSubtitle,
                style: AppTypography.caption.copyWith(color: scheme.hint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final settings = context.watch<AppSettingsProvider>();
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Divider(color: scheme.stroke),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              settings.isDarkMode ? LucideIcons.moon : LucideIcons.sun,
              size: 18,
              color: scheme.hint,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                settings.isDarkMode ? l10n.themeDark : l10n.themeLight,
                style: AppTypography.caption.copyWith(color: scheme.hint),
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
