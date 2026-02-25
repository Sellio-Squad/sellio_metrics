library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/navigation/app_navigation.dart';
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

    final items = AppNavigation.routes.map((route) {
      return SSidebarItemData(
        id: route.id,
        icon: route.icon,
        label: route.labelBuilder(l10n),
      );
    }).toList();

    final ids = items.map((i) => i.id).toList();
    final safeIndex = selectedIndex < ids.length ? selectedIndex : 0;

    return SSidebar(
      items: items,
      selectedItemId: ids[safeIndex],
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
            SSwitch(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleTheme(),
            ),
          ],
        ),
      ],
    );
  }
}
