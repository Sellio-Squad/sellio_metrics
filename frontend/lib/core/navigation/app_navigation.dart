import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../l10n/app_localizations.dart';
import '../../presentation/pages/leaderboard/leaderboard_page.dart';
import '../../presentation/pages/prs/open_prs_page.dart';
import '../../presentation/pages/analytics/analytics_page.dart';
import '../../presentation/pages/about/about_page.dart';
import '../../presentation/pages/setting/settings_page.dart';

class AppRoute {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) labelBuilder;
  final Widget page;

  const AppRoute({
    required this.id,
    required this.icon,
    required this.labelBuilder,
    required this.page,
  });
}

class AppNavigation {
  static final List<AppRoute> routes = [
    AppRoute(
      id: 'leaderboard',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navLeaderboard,
      page: const LeaderboardPage(),
    ),
    AppRoute(
      id: 'open_prs',
      icon: LucideIcons.gitPullRequest,
      labelBuilder: (l10n) => l10n.navOpenPrs,
      page: const OpenPrsPage(),
    ),
    AppRoute(
      id: 'analytics',
      icon: LucideIcons.barChart3,
      labelBuilder: (l10n) => l10n.navAnalytics,
      page: const AnalyticsPage(),
    ),
    AppRoute(
      id: 'about',
      icon: LucideIcons.info,
      labelBuilder: (l10n) => l10n.navAbout,
      page: const AboutPage(),
    ),
    AppRoute(
      id: 'settings',
      icon: LucideIcons.settings,
      labelBuilder: (l10n) => l10n.navSettings,
      page: const SettingsPage(),
    ),
  ];
}
