/// Sellio Metrics — Leaderboard Card Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/collaboration_entity.dart';

class LeaderboardCard extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {


    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.isDark ? SellioColors.darkSurface : SellioColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Leaderboard',
                style: AppTypography.title.copyWith(
                  color: context.isDark ? Colors.white : SellioColors.gray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildRow(context, index, item);
          }),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    LeaderboardEntry entry,
  ) {
    final medals = ['🥇', '🥈', '🥉'];
    final medal = index < 3 ? medals[index] : '${index + 1}';

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
                color: context.isDark ? Colors.white54 : SellioColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          HuxAvatar(name: entry.developer, size: HuxAvatarSize.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.developer,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.isDark ? Colors.white : SellioColors.gray700,
                  ),
                ),
                Text(
                  '${entry.prsCreated} PRs · ${entry.reviewsGiven} reviews · ${entry.commentsGiven} comments',
                  style: AppTypography.caption.copyWith(
                    color: context.isDark ? Colors.white38 : SellioColors.textTertiary,
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
              color: SellioColors.primaryIndigo.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '${entry.totalScore}',
              style: AppTypography.caption.copyWith(
                color: SellioColors.primaryIndigo,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
