import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/sellio_colors.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final primaryEntries = <MapEntry<int, AppRoute>>[];
    for (var i = 0; i < AppNavigation.routes.length; i++) {
      if (AppNavigation.routes[i].primaryNav) {
        primaryEntries.add(MapEntry(i, AppNavigation.routes[i]));
      }
    }

    // Determine if current route is a primary route
    int? activePrimaryIndex;
    for (var i = 0; i < primaryEntries.length; i++) {
      if (primaryEntries[i].key == currentIndex) {
        activePrimaryIndex = i;
        break;
      }
    }

    final isOnSecondaryPage = activePrimaryIndex == null;

    // If on secondary page, highlight the "More" item
    final selectedNavIndex =
        isOnSecondaryPage ? primaryEntries.length : activePrimaryIndex;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.stroke, width: 0.5),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: (index) {
          if (index < primaryEntries.length) {
            onTap(primaryEntries[index].key);
          } else {
            _showMoreSheet(context, l10n, scheme);
          }
        },
        backgroundColor: scheme.surfaceLow,
        indicatorColor: scheme.primaryVariant,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          ...primaryEntries.map((entry) {
            return NavigationDestination(
              icon: Icon(entry.value.icon, size: 22),
              selectedIcon: Icon(entry.value.icon, size: 22, color: scheme.primary),
              label: entry.value.labelBuilder(l10n),
            );
          }),
          NavigationDestination(
            icon: Badge(
              // Show a dot when user is on a secondary page
              isLabelVisible: isOnSecondaryPage,
              smallSize: 6,
              child: const Icon(Icons.more_horiz, size: 22),
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(
    BuildContext context,
    AppLocalizations l10n,
    SellioColorScheme scheme,
  ) {
    final secondaryEntries = <MapEntry<int, AppRoute>>[];
    for (var i = 0; i < AppNavigation.routes.length; i++) {
      if (!AppNavigation.routes[i].primaryNav) {
        secondaryEntries.add(MapEntry(i, AppNavigation.routes[i]));
      }
    }

    // Group secondary items by their NavGroup for better scannability
    final grouped = <NavGroup, List<MapEntry<int, AppRoute>>>{};
    for (final entry in secondaryEntries) {
      grouped.putIfAbsent(entry.value.group, () => []).add(entry);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceLow,
      isScrollControlled: true, // ← Allows proper sizing
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle bar ──
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.hint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'More Options',
                    style: TextStyle(
                      color: scheme.title,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Grouped items ──
                for (final group in NavGroup.values)
                  if (grouped.containsKey(group)) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        top: 12,
                        bottom: 4,
                      ),
                      child: Text(
                        group.label(l10n),
                        style: TextStyle(
                          color: scheme.hint,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...grouped[group]!.map((entry) {
                      final isActive = entry.key == currentIndex;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isActive
                                ? scheme.primaryVariant
                                : scheme.stroke.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            entry.value.icon,
                            color: isActive ? scheme.primary : scheme.body,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          entry.value.labelBuilder(l10n),
                          style: TextStyle(
                            color: isActive ? scheme.primary : scheme.title,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isActive
                            ? Icon(Icons.check_circle,
                                size: 18, color: scheme.primary)
                            : null,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onTap(entry.key);
                        },
                      );
                    }),
                  ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}