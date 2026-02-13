/// Sellio Metrics — PR List Tile Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/pr_model.dart';

class PrListTile extends StatelessWidget {
  final PrModel pr;

  const PrListTile({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HuxAvatar(
            name: pr.creator.login,
            size: HuxAvatarSize.small,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _infoChip(
                      '#${pr.prNumber}',
                      isDark,
                    ),
                    _infoChip(
                      pr.creator.login,
                      isDark,
                      icon: Icons.person_outline,
                    ),
                    _infoChip(
                      formatRelativeTime(pr.openedAt),
                      isDark,
                      icon: Icons.schedule,
                    ),
                    _infoChip(
                      '+${pr.diffStats.additions} / -${pr.diffStats.deletions}',
                      isDark,
                      icon: Icons.code,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          HuxBadge(
            label: pr.status.toUpperCase(),
            variant: _getBadgeVariant(pr.status),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String text, bool isDark, {IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
            fontSize: 11,
          ),
        ),
      ],
    );
  }


  HuxBadgeVariant _getBadgeVariant(String status) {
    switch (status) {
      case 'merged':
        return HuxBadgeVariant.primary;
      case 'closed':
        return HuxBadgeVariant.error;
      case 'approved':
        return HuxBadgeVariant.success;
      default:
        return HuxBadgeVariant.secondary;
    }
  }
}
