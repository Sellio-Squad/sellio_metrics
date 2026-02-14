/// Sellio Metrics — Team Page
///
/// Displays leaderboard and team structure.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/leaderboard_card.dart';
import '../widgets/team_structure_card.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Team Structure section
              const TeamStructureCard(),

              const SizedBox(height: AppSpacing.xxl),

              // Leaderboard section
              LeaderboardCard(entries: provider.leaderboard),
            ],
          ),
        );
      },
    );
  }
}
