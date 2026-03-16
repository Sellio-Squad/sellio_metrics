import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../design_system/design_system.dart';
import '../../core/di/service_locator.dart';
import '../../presentation/pages/leaderboard/leaderboard_page.dart';
import '../../presentation/pages/members/members_page.dart';
import '../../presentation/pages/prs/open_prs_page.dart';
import '../../presentation/pages/about/about_page.dart';
import '../../presentation/pages/meetings/meetings_page.dart';
import '../../presentation/pages/setting/settings_page.dart';
import '../../presentation/pages/logs/logs_page.dart';
import '../../presentation/pages/observability/observability_page.dart';
import '../../presentation/pages/dashboard_page.dart';
import '../../presentation/providers/leaderboard_provider.dart';
import '../../presentation/providers/member_provider.dart';
import '../../presentation/providers/pr_data_provider.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../presentation/providers/meetings_provider.dart';
import '../../presentation/providers/meet_events_provider.dart';
import '../../presentation/providers/health_status_provider.dart';
import '../../presentation/providers/logs_provider.dart';

class AppRoute {
  final String id;
  final String path;
  final IconData icon;
  final String Function(AppLocalizations) labelBuilder;
  final WidgetBuilder pageBuilder;
  final bool showDateFilter;

  const AppRoute({
    required this.id,
    required this.path,
    required this.icon,
    required this.labelBuilder,
    required this.pageBuilder,
    this.showDateFilter = true,
  });
}

class AppNavigation {
  static final List<AppRoute> routes = [
    AppRoute(
      id: 'leaderboard',
      path: '/leaderboard',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navLeaderboard,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: sl.get<LeaderboardProvider>(),
        child: const LeaderboardPage(),
      ),
    ),
    AppRoute(
      id: 'members',
      path: '/members',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navMembers,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: sl.get<MemberProvider>(),
        child: const MembersPage(),
      ),
    ),
    AppRoute(
      id: 'open_prs',
      path: '/prs',
      icon: LucideIcons.gitPullRequest,
      labelBuilder: (l10n) => l10n.navOpenPrs,
      pageBuilder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sl.get<PrDataProvider>()),
          ChangeNotifierProvider.value(value: sl.get<AnalyticsProvider>()),
        ],
        child: const OpenPrsPage(),
      ),
    ),
    AppRoute(
      id: 'about',
      path: '/about',
      icon: LucideIcons.info,
      labelBuilder: (l10n) => l10n.navAbout,
      pageBuilder: (_) => const AboutPage(),
      showDateFilter: false,
    ),
    AppRoute(
      id: 'meetings',
      path: '/meetings',
      icon: LucideIcons.calendar,
      labelBuilder: (l10n) => l10n.navMeetings,
      pageBuilder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sl.get<MeetingsProvider>()),
          ChangeNotifierProvider.value(value: sl.get<MeetEventsProvider>()),
        ],
        child: const MeetingsPage(),
      ),
      showDateFilter: false,
    ),
    AppRoute(
      id: 'settings',
      path: '/settings',
      icon: LucideIcons.settings,
      labelBuilder: (l10n) => l10n.navSettings,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: sl.get<HealthStatusProvider>()..fetchAll()..startAutoRefresh(),
        child: const SettingsPage(),
      ),
      showDateFilter: false,
    ),
    AppRoute(
      id: 'logs',
      path: '/logs',
      icon: LucideIcons.fileText,
      labelBuilder: (l10n) => l10n.navLogs,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: sl.get<LogsProvider>()..fetchLogs(),
        child: const LogsPage(),
      ),
      showDateFilter: false,
    ),
    AppRoute(
      id: 'observability',
      path: '/observability',
      icon: LucideIcons.activity,
      labelBuilder: (l10n) => l10n.navObservability,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: sl.get<HealthStatusProvider>()..fetchAll()..startAutoRefresh(),
        child: const ObservabilityPage(),
      ),
      showDateFilter: false,
    ),
  ];

  static final router = GoRouter(
    initialLocation: '/leaderboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardPage(navigationShell: navigationShell);
        },
        branches: routes.map((route) {
          return StatefulShellBranch(
            routes: [
              GoRoute(
                path: route.path,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: route.pageBuilder(context),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ],
  );
}
