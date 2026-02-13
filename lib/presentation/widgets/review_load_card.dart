/// Sellio Metrics — Review Load Card Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/collaboration_entity.dart';

class ReviewLoadCard extends StatelessWidget {
  final List<ReviewLoadEntry> entries;

  const ReviewLoadCard({super.key, required this.entries});

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
              const Text('⚖️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Review Load',
                style: AppTypography.title.copyWith(
                  color: context.isDark ? Colors.white : SellioColors.gray700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.take(8).map((entry) => _buildRow(context, entry)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ReviewLoadEntry entry) {
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
                        color: context.isDark ? Colors.white : SellioColors.gray700,
                      ),
                    ),
                    Text(
                      '${entry.reviewsGiven} reviews',
                      style: AppTypography.caption.copyWith(
                        color: context.isDark ? Colors.white54 : SellioColors.textSecondary,
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
