import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_constants.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_header.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_group_label.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_nav_item.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_footer.dart';

/// The main sidebar navigation widget.
///
/// Acts purely as an **orchestrator** — it delegates every visual concern
/// to the focused components in this directory:
/// - [SidebarHeader] — branding + collapse toggle
/// - [SidebarGroupLabel] — nav group section labels
/// - [SidebarNavItem] — individual navigation items
/// - [SidebarFooter] — theme toggle
class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;

  /// Null on medium screens where the toggle is hidden.
  final VoidCallback? onToggleCollapse;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final grouped = AppNavigation.groupedRoutes;

    return AnimatedContainer(
      duration: sidebarAnimDuration,
      curve: Curves.easeInOut,
      width: isCollapsed ? sidebarCollapsedWidth : sidebarExpandedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(
          right: BorderSide(color: scheme.stroke, width: 1),
        ),
      ),
      child: Column(
        children: [
          SidebarHeader(
            isCollapsed: isCollapsed,
            onToggleCollapse: onToggleCollapse,
          ),
          Divider(height: 1, color: scheme.stroke),
          Expanded(
            child: _NavList(
              grouped: grouped,
              isCollapsed: isCollapsed,
              selectedIndex: selectedIndex,
              onItemSelected: onItemSelected,
              l10n: l10n,
            ),
          ),
          Divider(height: 1, color: scheme.stroke),
          SidebarFooter(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

/// Scrollable list of grouped navigation items.
class _NavList extends StatelessWidget {
  final Map<NavGroup, List<MapEntry<int, AppRoute>>> grouped;
  final bool isCollapsed;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final AppLocalizations l10n;

  const _NavList({
    required this.grouped,
    required this.isCollapsed,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      children: [
        for (final group in NavGroup.values)
          if (grouped.containsKey(group)) ...[
            if (!isCollapsed)
              SidebarGroupLabel(group: group, l10n: l10n)
            else
              const SizedBox(height: AppSpacing.sm),
            ...grouped[group]!.map(
              (entry) => SidebarNavItem(
                route: entry.value,
                isSelected: selectedIndex == entry.key,
                isCollapsed: isCollapsed,
                onTap: () => onItemSelected(entry.key),
                l10n: l10n,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
