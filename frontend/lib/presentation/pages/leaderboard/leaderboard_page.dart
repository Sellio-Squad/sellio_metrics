library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/design_system.dart';
import '../../providers/dashboard_provider.dart';
import 'leaderboard_section.dart';
import '../../providers/app_settings_provider.dart';
import '../../widgets/common/loading_screen.dart';
import '../../widgets/common/error_screen.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();
      dashboard.ensureDataLoaded(settings.selectedRepos);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        if (provider.status == DashboardStatus.loading) {
          return const LoadingScreen();
        }
        if (provider.status == DashboardStatus.error) {
          return ErrorScreen(
            onRetry: () {
              final settings = context.read<AppSettingsProvider>();
              provider.loadData(repos: settings.selectedRepos);
            },
          );
        }

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LeaderboardSection(entries: provider.leaderboard),
          ),);
      },
    );
  }
}
