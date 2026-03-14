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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLeaderboard();
    });
  }

  void _loadLeaderboard() {
    context.read<LeaderboardProvider>().fetchLeaderboard();
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
