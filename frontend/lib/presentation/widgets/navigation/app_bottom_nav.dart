library;

import 'package:flutter/material.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/navigation/app_navigation.dart';

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
    final safeIndex = currentIndex < AppNavigation.routes.length ? currentIndex : 0;

    return NavigationBar(
      selectedIndex: safeIndex,
      onDestinationSelected: onTap,
      backgroundColor: scheme.surfaceLow,
      indicatorColor: scheme.primaryVariant,
      destinations: AppNavigation.routes.map((route) {
        return NavigationDestination(
          icon: Icon(route.icon),
          label: route.labelBuilder(l10n),
        );
      }).toList(),
    );
  }
}
