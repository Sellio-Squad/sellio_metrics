/// Sellio Metrics — Review Load Card Widget
library;

import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/collaboration_entity.dart';

class ReviewLoadCard extends StatelessWidget {
  final List<ReviewLoadEntry> entries;

  const ReviewLoadCard({super.key, required this.entries});

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
              const Text('⚖️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.sectionReviewLoad,
                style: AppTypography.title.copyWith(color: scheme.title),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...entries.take(8).map((entry) => _ReviewRow(
                entry: entry,
                maxReviews: _maxReviews,
              )),
        ],
      ),
    );
  }

  int get _maxReviews => entries.isNotEmpty
      ? entries.map((e) => e.reviewsGiven).reduce((a, b) => a > b ? a : b)
      : 1;
}

class _ReviewRow extends StatelessWidget {
  final ReviewLoadEntry entry;
  final int maxReviews;

  const _ReviewRow({required this.entry, required this.maxReviews});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
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
                        color: scheme.title,
                      ),
                    ),
                    Text(
                      '${entry.reviewsGiven} reviews',
                      style: AppTypography.caption.copyWith(
                        color: scheme.hint,
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
