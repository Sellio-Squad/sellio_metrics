library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/design_system.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../widgets/common/loading_screen.dart';
import '../../widgets/common/error_screen.dart';
import 'leaderboard_section.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late AppSettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppSettingsProvider>();
    _settings.addListener(_onSettingsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) _loadLeaderboard();
  }

  void _loadLeaderboard() {
    final repoNames = _settings.selectedRepos.map((r) => r.fullName).toList();
    if (repoNames.isEmpty) return;
    context.read<LeaderboardProvider>().fetchLeaderboard(repoNames);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardProvider>(
      builder: (context, leaderboardProvider, _) {
        if (leaderboardProvider.isLoading) {
          return const LoadingScreen();
        }
        if (leaderboardProvider.error != null &&
            leaderboardProvider.leaderboard.isEmpty) {
          return ErrorScreen(onRetry: _loadLeaderboard);
        }

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LeaderboardSection(entries: leaderboardProvider.leaderboard),
          ),
        );
      },
    );
  }
}
