/// Sellio Metrics — PR List Tile Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/pr_entity.dart';

class PrListTile extends StatelessWidget {
  final PrEntity pr;

  const PrListTile({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {


    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark ? SellioColors.darkSurface : SellioColors.lightSurface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
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
                    color: context.isDark ? Colors.white : SellioColors.gray700,
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
                      context.isDark,
                    ),
                    _infoChip(
                      pr.creator.login,
                      context.isDark,
                      icon: Icons.person_outline,
                    ),
                    _infoChip(
                      formatRelativeTime(pr.openedAt),
                      context.isDark,
                      icon: Icons.schedule,
                    ),
                    _infoChip(
                      '+${pr.diffStats.additions} / -${pr.diffStats.deletions}',
                      context.isDark,
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

  Widget _infoChip(String text, bool contextIsDark, {IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 12,
            color: contextIsDark ? Colors.white38 : SellioColors.textTertiary,
          ),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: contextIsDark ? Colors.white54 : SellioColors.textSecondary,
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
