/// Sellio Metrics — Review Load Card Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/collaboration_model.dart';

class ReviewLoadCard extends StatelessWidget {
  final List<ReviewLoadEntry> entries;

  const ReviewLoadCard({super.key, required this.entries});

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
              const Text('⚖️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Review Load',
                style: AppTypography.title.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.take(8).map((entry) => _buildRow(context, entry, isDark)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ReviewLoadEntry entry, bool isDark) {
    final maxReviews = entries.isNotEmpty
        ? entries.map((e) => e.reviewsGiven).reduce((a, b) => a > b ? a : b)
        : 1;
    final progress = maxReviews > 0 ? entry.reviewsGiven / maxReviews : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          HuxAvatar(name: entry.developer, size: HuxAvatarSize.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.developer,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                      ),
                    ),
                    Text(
                      '${entry.reviewsGiven} reviews',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                HuxProgress(
                  value: progress,
                  size: HuxProgressSize.medium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
