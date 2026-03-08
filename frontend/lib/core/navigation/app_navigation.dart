import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../presentation/pages/leaderboard/leaderboard_page.dart';
import '../../presentation/pages/members/members_page.dart';
import '../../presentation/pages/prs/open_prs_page.dart';
import '../../presentation/pages/about/about_page.dart';
import '../../presentation/pages/meetings/meetings_page.dart';
import '../../presentation/pages/setting/settings_page.dart';

class AppRoute {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations) labelBuilder;
  final WidgetBuilder pageBuilder;

  const AppRoute({
    required this.id,
    required this.icon,
    required this.labelBuilder,
    required this.pageBuilder,
  });
}

class AppNavigation {
  static final List<AppRoute> routes = [
    AppRoute(
      id: 'leaderboard',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navLeaderboard,
      pageBuilder: (_) => const LeaderboardPage(),
    ),
    AppRoute(
      id: 'members',
      icon: LucideIcons.users,
      labelBuilder: (l10n) => l10n.navMembers,
      pageBuilder: (_) => MembersPage(),
    ),
    AppRoute(
      id: 'open_prs',
      icon: LucideIcons.gitPullRequest,
      labelBuilder: (l10n) => l10n.navOpenPrs,
      pageBuilder: (_) => OpenPrsPage(),
    ),

    AppRoute(
      id: 'about',
      icon: LucideIcons.info,
      labelBuilder: (l10n) => l10n.navAbout,
      pageBuilder: (_) => AboutPage(),
    ),
    AppRoute(
      id: 'meetings',
      icon: LucideIcons.calendar,
      labelBuilder: (l10n) => l10n.navMeetings,
      pageBuilder: (_) => MeetingsPage(),
    ),
    AppRoute(
      id: 'settings',
      icon: LucideIcons.settings,
      labelBuilder: (l10n) => l10n.navSettings,
      pageBuilder: (_) => SettingsPage(),
    ),
  ];
}
