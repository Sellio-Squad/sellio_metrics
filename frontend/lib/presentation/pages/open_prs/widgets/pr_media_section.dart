/// PR Media Section
///
/// Detects images and videos in the PR body and displays bonus scoring.
library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/pr_entity.dart';
import '../../../../domain/services/pr_analysis_service.dart';

class PrMediaSection extends StatelessWidget {
  final PrEntity pr;

  const PrMediaSection({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final hasImages = PrAnalysisService.hasImages(pr);
    final hasVideos = PrAnalysisService.hasVideos(pr);
    final bonusPoints = PrAnalysisService.calculateBonusPoints(pr);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.perm_media_outlined, size: 16, color: scheme.hint),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Media & Visuals',
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (!hasImages && !hasVideos)
            _NoMediaHint(scheme: scheme)
          else ...[
            if (hasImages) _MediaBadge.image(scheme: scheme),
            if (hasVideos) ...[
              if (hasImages) const SizedBox(height: AppSpacing.sm),
              _MediaBadge.video(scheme: scheme),
            ],
            const SizedBox(height: AppSpacing.md),
            _BonusPointsChip(
              points: bonusPoints,
              scheme: scheme,
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _MediaBadge({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });

  factory _MediaBadge.image({required dynamic scheme}) => _MediaBadge(
        icon: Icons.image_outlined,
        label: 'Images detected',
        description: '+2 bonus points for including screenshots',
        color: Colors.blue,
      );

  factory _MediaBadge.video({required dynamic scheme}) => _MediaBadge(
        icon: Icons.videocam_outlined,
        label: '⭐ Video attached',
        description: '+5 bonus points — PR is starred!',
        color: Colors.amber,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: scheme.title,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: scheme.body,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusPointsChip extends StatelessWidget {
  final int points;
  final dynamic scheme;

  const _BonusPointsChip({required this.points, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.1),
            scheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            '+$points bonus points',
            style: AppTypography.caption.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMediaHint extends StatelessWidget {
  final dynamic scheme;

  const _NoMediaHint({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: SellioColors.amber.withValues(alpha: 0.06),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: SellioColors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            size: 14,
            color: SellioColors.amber,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No media found. Add screenshots for +2 points or a video for ⭐ starring!',
              style: AppTypography.caption.copyWith(
                color: scheme.body,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
