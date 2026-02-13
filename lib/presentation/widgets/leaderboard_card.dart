/// Sellio Metrics — Leaderboard Card Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/collaboration_model.dart';

class LeaderboardCard extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const LeaderboardCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE5E7EB),
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
                  color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildRow(context, index, item, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    LeaderboardEntry entry,
    bool isDark,
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
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                ),
                Text(
                  '${entry.prsCreated} PRs · ${entry.reviewsGiven} reviews · ${entry.commentsGiven} comments',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
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
