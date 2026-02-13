/// Sellio Metrics — Team Page
///
/// Displays leaderboard and review load side by side.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/leaderboard_card.dart';
import '../widgets/review_load_card.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                // Desktop: side by side
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LeaderboardCard(entries: provider.leaderboard),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: ReviewLoadCard(entries: provider.reviewLoad),
                    ),
                  ],
                );
              }
              // Mobile: stacked
              return Column(
                children: [
                  LeaderboardCard(entries: provider.leaderboard),
                  const SizedBox(height: AppSpacing.xl),
                  ReviewLoadCard(entries: provider.reviewLoad),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
