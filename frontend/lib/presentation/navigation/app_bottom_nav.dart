import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
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

    // Build mapping: bottom nav position → actual route index
    final primaryRoutes = <MapEntry<int, AppRoute>>[];
    for (var i = 0; i < AppNavigation.routes.length; i++) {
      if (AppNavigation.routes[i].primaryNav) {
        primaryRoutes.add(MapEntry(i, AppNavigation.routes[i]));
      }
    }

    // Find which bottom nav item should be highlighted
    // If current route is secondary (not in bottom nav), highlight none (-1)
    int bottomIndex = -1;
    for (var i = 0; i < primaryRoutes.length; i++) {
      if (primaryRoutes[i].key == currentIndex) {
        bottomIndex = i;
        break;
      }
    }

    // If on a secondary page, show a "More" item as selected
    final showMore = bottomIndex == -1;
    final safeBottomIndex = showMore ? primaryRoutes.length : bottomIndex;

    return NavigationBar(
      selectedIndex: safeBottomIndex,
      onDestinationSelected: (index) {
        if (index < primaryRoutes.length) {
          // Tap on primary item → navigate
          onTap(primaryRoutes[index].key);
        } else {
          // Tap on "More" → open bottom sheet with secondary routes
          _showMoreSheet(context, l10n);
        }
      },
      backgroundColor: scheme.surfaceLow,
      indicatorColor: scheme.primaryVariant,
      destinations: [
        // Primary routes
        ...primaryRoutes.map((entry) {
          return NavigationDestination(
            icon: Icon(entry.value.icon),
            label: entry.value.labelBuilder(l10n),
          );
        }),
        // "More" overflow button
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }

  void _showMoreSheet(BuildContext context, AppLocalizations l10n) {
    final scheme = context.colors;
    final secondaryEntries = <MapEntry<int, AppRoute>>[];
    for (var i = 0; i < AppNavigation.routes.length; i++) {
      if (!AppNavigation.routes[i].primaryNav) {
        secondaryEntries.add(MapEntry(i, AppNavigation.routes[i]));
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.hint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary items
                ...secondaryEntries.map((entry) {
                  return ListTile(
                    leading: Icon(
                      entry.value.icon,
                      color: scheme.body,
                      size: 22,
                    ),
                    title: Text(
                      entry.value.labelBuilder(l10n),
                      style: TextStyle(
                        color: scheme.title,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      onTap(entry.key);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}