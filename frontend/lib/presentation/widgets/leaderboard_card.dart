/// Sellio Metrics — Leaderboard Card Widget
///
/// Displays ranked developer leaderboard.
/// Follows SRP — only responsible for rendering the leaderboard table.
library;

import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../domain/entities/collaboration_entity.dart';
import '../../l10n/app_localizations.dart';

class LeaderboardCard extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardCard({super.key, required this.entries});

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
          ...entries.asMap().entries.map((entry) =>
              _LeaderboardRow(index: entry.key, entry: entry.value)),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.index, required this.entry});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final medal = index < 3 ? _medals[index] : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal,
              style: TextStyle(
                fontSize: index < 3 ? 18 : 14,
                color: scheme.hint,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SAvatar(name: entry.developer, size: SAvatarSize.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.developer,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                ),
                Text(
                  '${entry.prsCreated} ${l10n.unitPrs} · '
                  '${entry.reviewsGiven} ${l10n.unitReviews} · '
                  '${entry.commentsGiven} ${l10n.unitComments}',
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryVariant,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '${entry.totalScore}',
              style: AppTypography.caption.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
