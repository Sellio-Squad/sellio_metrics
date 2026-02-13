/// Sellio Metrics — Bottleneck Item Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/bottleneck_entity.dart';

class BottleneckItem extends StatelessWidget {
  final BottleneckEntity bottleneck;

  const BottleneckItem({super.key, required this.bottleneck});

  @override
  Widget build(BuildContext context) {

    final severityColor = _getSeverityColor(bottleneck.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark ? SellioColors.darkSurface : SellioColors.lightSurface,
        borderRadius: AppRadius.mdAll,
        border: Border(
          left: BorderSide(color: severityColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  truncateText(bottleneck.title, 60),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.isDark ? Colors.white : SellioColors.gray700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '#${bottleneck.prNumber} by ${bottleneck.author}',
                  style: AppTypography.caption.copyWith(
                    color: context.isDark ? Colors.white54 : SellioColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              HuxBadge(
                label: bottleneck.severity.toUpperCase(),
                variant: _getBadgeVariant(bottleneck.severity),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${bottleneck.waitTimeDays.toStringAsFixed(1)}d waiting',
                style: AppTypography.caption.copyWith(
                  color: severityColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'high':
        return SellioColors.severityHigh;
      case 'medium':
        return SellioColors.severityMedium;
      default:
        return SellioColors.severityLow;
    }
  }

  HuxBadgeVariant _getBadgeVariant(String severity) {
    switch (severity) {
      case 'high':
        return HuxBadgeVariant.error;
      case 'medium':
        return HuxBadgeVariant.secondary;
      default:
        return HuxBadgeVariant.success;
    }
  }
}
