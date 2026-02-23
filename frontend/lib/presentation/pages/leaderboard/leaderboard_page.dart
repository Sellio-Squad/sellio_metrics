library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/design_system.dart';
import '../../providers/dashboard_provider.dart';
import 'leaderboard_section.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LeaderboardSection(entries: provider.leaderboard),
            ],
          ),
        );
      },
    );
  }
}
