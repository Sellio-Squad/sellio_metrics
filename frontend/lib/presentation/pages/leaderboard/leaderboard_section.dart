
import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/leaderboard_entry.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/leaderboard_row.dart';

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
          if (entries.isEmpty)
            _EmptyLeaderboard(scheme: scheme)
          else
            ...entries.asMap().entries.map(
              (entry) => LeaderboardRow(index: entry.key, entry: entry.value),
            ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  final dynamic scheme;
  const _EmptyLeaderboard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 48, color: scheme.hint),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No scores available yet',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sync a repo to start computing scores',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ],
        ),
      ),
    );
  }
}
