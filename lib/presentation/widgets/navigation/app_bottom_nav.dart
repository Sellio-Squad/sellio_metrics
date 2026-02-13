/// Sellio Metrics — App Bottom Navigation (Mobile)
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

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

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: context.isDark
          ? SellioColors.darkSurface
          : SellioColors.lightSurface,
      indicatorColor: SellioColors.primaryIndigo.withAlpha(30),
      destinations: [
        NavigationDestination(
          icon: const Icon(LucideIcons.barChart3),
          label: l10n.navAnalytics,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.gitPullRequest),
          label: l10n.navOpenPrs,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.users),
          label: l10n.navTeam,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.pieChart),
          label: l10n.navCharts,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.info),
          label: l10n.navAbout,
        ),
        NavigationDestination(
          icon: const Icon(LucideIcons.settings),
          label: l10n.navSettings,
        ),
      ],
    );
  }
}
