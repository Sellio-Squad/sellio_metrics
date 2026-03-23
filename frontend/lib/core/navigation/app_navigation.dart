import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/leaderboard_page.dart';
import 'package:sellio_metrics/presentation/pages/members/members_page.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/open_prs_page.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/pr_details_page.dart';
import 'package:sellio_metrics/presentation/pages/about/about_page.dart';
import 'package:sellio_metrics/presentation/pages/meetings/meetings_page.dart';
import 'package:sellio_metrics/presentation/pages/setting/settings_page.dart';
import 'package:sellio_metrics/presentation/pages/logs/logs_page.dart';
import 'package:sellio_metrics/presentation/pages/observability/observability_page.dart';
import 'package:sellio_metrics/presentation/pages/dashboard_page.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/providers/leaderboard_provider.dart';
import 'package:sellio_metrics/presentation/pages/members/providers/member_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/analytics_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meet_events_provider.dart';
import 'package:sellio_metrics/presentation/pages/observability/providers/health_status_provider.dart';
import 'package:sellio_metrics/presentation/pages/logs/providers/logs_provider.dart';

class AppRoute {
  final String id;
  final String path;
  final IconData icon;
  final String Function(AppLocalizations) labelBuilder;
  final WidgetBuilder pageBuilder;

  const AppRoute({
    required this.id,
    required this.path,
    required this.icon,
    required this.labelBuilder,
    required this.pageBuilder,
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
        value: getIt<LeaderboardProvider>(),
        child: const LeaderboardPage(),
      ),
    ),
    AppRoute(
      id: 'members',
      path: '/members',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navMembers,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<MemberProvider>(),
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
          ChangeNotifierProvider.value(value: getIt<PrDataProvider>()),
          ChangeNotifierProvider.value(value: getIt<AnalyticsProvider>()),
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
    ),
    AppRoute(
      id: 'meetings',
      path: '/meetings',
      icon: LucideIcons.calendar,
      labelBuilder: (l10n) => l10n.navMeetings,
      pageBuilder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: getIt<MeetingsProvider>()),
          ChangeNotifierProvider.value(value: getIt<MeetEventsProvider>()),
        ],
        child: const MeetingsPage(),
      ),
    ),
    AppRoute(
      id: 'settings',
      path: '/settings',
      icon: LucideIcons.settings,
      labelBuilder: (l10n) => l10n.navSettings,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<HealthStatusProvider>()..fetchAll()..startAutoRefresh(),
        child: const SettingsPage(),
      ),
    ),
    AppRoute(
      id: 'logs',
      path: '/logs',
      icon: LucideIcons.fileText,
      labelBuilder: (l10n) => l10n.navLogs,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<LogsProvider>()..fetchLogs(),
        child: const LogsPage(),
      ),
    ),
    AppRoute(
      id: 'observability',
      path: '/observability',
      icon: LucideIcons.activity,
      labelBuilder: (l10n) => l10n.navObservability,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<HealthStatusProvider>()..fetchAll()..startAutoRefresh(),
        child: const ObservabilityPage(),
      ),
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
                routes: route.id == 'open_prs'
                    ? [
                        GoRoute(
                          path: ':prNumber',
                          pageBuilder: (context, state) {
                            final prNumber = int.tryParse(
                                  state.pathParameters['prNumber'] ?? '',
                                ) ??
                                0;
                            return NoTransitionPage(
                              key: state.pageKey,
                              child: MultiProvider(
                                providers: [
                                  ChangeNotifierProvider.value(
                                    value: getIt<PrDataProvider>(),
                                  ),
                                  ChangeNotifierProvider.value(
                                    value: getIt<AnalyticsProvider>(),
                                  ),
                                ],
                                child: PrDetailsPage(prNumber: prNumber),
                              ),
                            );
                          },
                        ),
                      ]
                    : [],
              ),
            ],
          );
        }).toList(),
      ),
    ],
  );
}
