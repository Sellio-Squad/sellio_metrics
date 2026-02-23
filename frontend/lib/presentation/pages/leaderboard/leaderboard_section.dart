library;

import 'package:flutter/material.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../l10n/app_localizations.dart';
import 'leaderboard_row.dart';

class LeaderboardSection extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.sectionLeaderboard,
                style: AppTypography.title.copyWith(color: scheme.title),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.asMap().entries.map(
            (entry) => LeaderboardRow(index: entry.key, entry: entry.value),
          ),
        ],
      ),
    );
  }
}
