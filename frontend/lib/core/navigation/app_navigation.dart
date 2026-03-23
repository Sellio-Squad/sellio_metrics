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

// ─── Route Groups ────────────────────────────────────────────
enum NavGroup { team, product, system }

extension NavGroupX on NavGroup {
  String label(AppLocalizations l10n) {
    switch (this) {
      case NavGroup.team:
        return 'TEAM'; // TODO: Add l10n.navGroupTeam
      case NavGroup.product:
        return 'PRODUCT'; // TODO: Add l10n.navGroupProduct
      case NavGroup.system:
        return 'SYSTEM'; // TODO: Add l10n.navGroupSystem
    }
  }
}

// ─── Route Definition ────────────────────────────────────────
class AppRoute {
  final String id;
  final String path;
  final IconData icon;
  final NavGroup group;

  /// Show in mobile bottom navigation bar (max 4 recommended)
  final bool primaryNav;
  final String Function(AppLocalizations) labelBuilder;
  final WidgetBuilder pageBuilder;

  const AppRoute({
    required this.id,
    required this.path,
    required this.icon,
    required this.group,
    required this.primaryNav,
    required this.labelBuilder,
    required this.pageBuilder,
  });
}

// ─── Navigation Config ───────────────────────────────────────
class AppNavigation {
  AppNavigation._();

  // ── Route order matters — indices map to goBranch(index) ──
  static final List<AppRoute> routes = [
    // ── Team (primary) ──────────────────────────────────────
    AppRoute(
      id: 'leaderboard',
      path: '/leaderboard',
      icon: LucideIcons.trophy, // ← Fixed: was same as Members
      group: NavGroup.team,
      primaryNav: true,
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
      group: NavGroup.team,
      primaryNav: true,
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
      group: NavGroup.team,
      primaryNav: true,
      labelBuilder: (l10n) => l10n.navOpenPrs,
      pageBuilder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: getIt<PrDataProvider>()),
          ChangeNotifierProvider.value(value: getIt<AnalyticsProvider>()),
        ],
        child: const OpenPrsPage(),
      ),
    ),

    // ── Product (Meetings is primary, About is secondary) ───
    AppRoute(
      id: 'meetings',
      path: '/meetings',
      icon: LucideIcons.calendar,
      group: NavGroup.product,
      primaryNav: true,
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
      id: 'about',
      path: '/about',
      icon: LucideIcons.info,
      group: NavGroup.product,
      primaryNav: false,
      labelBuilder: (l10n) => l10n.navAbout,
      pageBuilder: (_) => const AboutPage(),
    ),

    // ── System (all secondary) ──────────────────────────────
    AppRoute(
      id: 'settings',
      path: '/settings',
      icon: LucideIcons.settings,
      group: NavGroup.system,
      primaryNav: false,
      labelBuilder: (l10n) => l10n.navSettings,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<HealthStatusProvider>()
          ..fetchAll()
          ..startAutoRefresh(),
        child: const SettingsPage(),
      ),
    ),
    AppRoute(
      id: 'logs',
      path: '/logs',
      icon: LucideIcons.fileText,
      group: NavGroup.system,
      primaryNav: false,
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
      group: NavGroup.system,
      primaryNav: false,
      labelBuilder: (l10n) => l10n.navObservability,
      pageBuilder: (_) => ChangeNotifierProvider.value(
        value: getIt<HealthStatusProvider>()
          ..fetchAll()
          ..startAutoRefresh(),
        child: const ObservabilityPage(),
      ),
    ),
  ];

  // ── Helpers ───────────────────────────────────────────────
  static List<AppRoute> get primaryRoutes =>
      routes.where((r) => r.primaryNav).toList();

  static List<AppRoute> get secondaryRoutes =>
      routes.where((r) => !r.primaryNav).toList();

  /// Routes grouped by NavGroup, preserving order.
  static Map<NavGroup, List<MapEntry<int, AppRoute>>> get groupedRoutes {
    final map = <NavGroup, List<MapEntry<int, AppRoute>>>{};
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      map.putIfAbsent(route.group, () => []).add(MapEntry(i, route));
    }
    return map;
  }

  // ── Router ────────────────────────────────────────────────
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