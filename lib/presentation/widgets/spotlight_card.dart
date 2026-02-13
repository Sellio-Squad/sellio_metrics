/// Sellio Metrics — Spotlight Card Widget
library;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/kpi_model.dart';

class SpotlightCard extends StatelessWidget {
  final String title;
  final String emoji;
  final SpotlightMetric? metric;
  final Color accentColor;

  const SpotlightCard({
    super.key,
    required this.title,
    required this.emoji,
    this.metric,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
            accentColor.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (metric != null) ...[
            Text(
              metric!.user,
              style: AppTypography.subtitle.copyWith(
                color: isDark ? Colors.white : const Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric!.label,
              style: AppTypography.caption.copyWith(
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ] else
            Text(
              'No data',
              style: AppTypography.caption.copyWith(
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }
}
