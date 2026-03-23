import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';
import 'package:sellio_metrics/presentation/pages/setting/providers/app_settings_provider.dart';

const double _expandedWidth = 240;
const double _collapsedWidth = 68;
const Duration _animDuration = Duration(milliseconds: 200);

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleCollapse;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final grouped = AppNavigation.groupedRoutes;

    return AnimatedContainer(
      duration: _animDuration,
      curve: Curves.easeInOut,
      width: isCollapsed ? _collapsedWidth : _expandedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(
          right: BorderSide(color: scheme.stroke, width: 1),
        ),
      ),
      child: Column(
        children: [
          _Header(
            isCollapsed: isCollapsed,
            onToggleCollapse: onToggleCollapse,
          ),
          Divider(height: 1, color: scheme.stroke),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              children: [
                for (final group in NavGroup.values)
                  if (grouped.containsKey(group)) ...[
                    if (!isCollapsed)
                      _GroupLabel(group: group, l10n: l10n)
                    else
                      const SizedBox(height: AppSpacing.sm),
                    ...grouped[group]!.map(
                          (entry) => _NavItem(
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
            ),
          ),
          Divider(height: 1, color: scheme.stroke),
          _Footer(isCollapsed: isCollapsed),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const _Header({
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            _Logo(scheme: scheme),
            const SizedBox(height: AppSpacing.sm),
            _CollapseToggle(
              isCollapsed: isCollapsed,
              onTap: onToggleCollapse,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _Logo(scheme: scheme),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appTitle,
                  style: AppTypography.subtitle.copyWith(
                    color: scheme.title,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.appSubtitle,
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _CollapseToggle(
            isCollapsed: isCollapsed,
            onTap: onToggleCollapse,
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final SellioColorScheme scheme;
  const _Logo({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const _CollapseToggle({
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      // ─── Soft hover ──────────────────────────────
      hoverColor: scheme.stroke.withValues(alpha: 0.4),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: AnimatedRotation(
            duration: _animDuration,
            turns: isCollapsed ? 0.5 : 0,
            child: Icon(
              LucideIcons.panelLeftClose,
              size: 16,
              color: scheme.hint,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GROUP LABEL
// ═══════════════════════════════════════════════════════════════
class _GroupLabel extends StatelessWidget {
  final NavGroup group;
  final AppLocalizations l10n;

  const _GroupLabel({required this.group, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        group.label(l10n),
        style: AppTypography.overline.copyWith(
          color: scheme.hint,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NAV ITEM — Soft subtle hover
// ═══════════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final AppRoute route;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _NavItem({
    required this.route,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final label = route.labelBuilder(l10n);
    final iconColor = isSelected ? scheme.primary : scheme.hint;
    final textColor = isSelected ? scheme.title : scheme.body;
    final bg = isSelected ? scheme.primaryVariant : Colors.transparent;

    // ─── Shared hover/splash: very soft, barely visible ───
    final hoverColor = isSelected
        ? Colors.transparent
        : scheme.stroke.withValues(alpha: 0.3);
    final splashColor = scheme.primary.withValues(alpha: 0.05);

    if (isCollapsed) {
      return _collapsed(scheme, iconColor, bg, hoverColor, splashColor, label);
    }
    return _expanded(scheme, iconColor, textColor, bg, hoverColor, splashColor, label);
  }

  Widget _expanded(
      SellioColorScheme scheme,
      Color iconColor,
      Color textColor,
      Color bg,
      Color hoverColor,
      Color splashColor,
      String label,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: bg,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          hoverColor: hoverColor,
          splashColor: splashColor,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Active indicator
                  if (isSelected)
                    Container(
                      width: 3,
                      height: 18,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                  Icon(route.icon, size: 20, color: iconColor),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: textColor,
                        fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsed(
      SellioColorScheme scheme,
      Color iconColor,
      Color bg,
      Color hoverColor,
      Color splashColor,
      String label,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Tooltip(
        message: label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: bg,
          borderRadius: AppRadius.smAll,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.smAll,
            hoverColor: hoverColor,
            splashColor: splashColor,
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: 40,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Container(
                        width: 3,
                        height: 18,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: AppRadius.smAll,
                        ),
                      ),
                    Icon(route.icon, size: 20, color: iconColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  final bool isCollapsed;
  const _Footer({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final settings = context.watch<AppSettingsProvider>();
    final l10n = AppLocalizations.of(context);
    final isDark = settings.isDarkMode;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Tooltip(
          message: isDark ? l10n.themeDark : l10n.themeLight,
          child: InkWell(
            onTap: () => settings.toggleTheme(),
            borderRadius: AppRadius.smAll,
            hoverColor: scheme.stroke.withValues(alpha: 0.3),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: 36,
              child: Center(
                child: Icon(
                  isDark ? LucideIcons.moon : LucideIcons.sun,
                  size: 18,
                  color: scheme.hint,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            isDark ? LucideIcons.moon : LucideIcons.sun,
            size: 18,
            color: scheme.hint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isDark ? l10n.themeDark : l10n.themeLight,
              style: AppTypography.caption.copyWith(color: scheme.hint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SSwitch(
            value: isDark,
            onChanged: (_) => settings.toggleTheme(),
          ),
        ],
      ),
    );
  }
}