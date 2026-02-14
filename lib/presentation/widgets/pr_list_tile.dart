/// Sellio Metrics — PR List Tile Widget
///
/// Clickable, hoverable PR tile with type badge.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/enums/pr_type.dart';

class PrListTile extends StatefulWidget {
  final PrEntity pr;

  const PrListTile({super.key, required this.pr});

  @override
  State<PrListTile> createState() => _PrListTileState();
}

class _PrListTileState extends State<PrListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final pr = widget.pr;
    final prType = PrType.fromTitle(pr.title);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openPrUrl(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.005))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: context.isDark
                ? SellioColors.darkSurface
                : SellioColors.lightSurface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _isHovered
                  ? SellioColors.primaryIndigo.withValues(alpha: 0.4)
                  : (context.isDark ? Colors.white10 : SellioColors.gray300),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: SellioColors.primaryIndigo.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
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
                        color: context.isDark
                            ? Colors.white
                            : SellioColors.gray700,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // PR Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: prType.color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      prType.label,
                      style: AppTypography.caption.copyWith(
                        color: prType.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Status badge
                  HuxBadge(
                    label: pr.status.toUpperCase(),
                    variant: _getBadgeVariant(pr.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrUrl() {
    final uri = Uri.tryParse(widget.pr.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    return switch (status) {
      'merged' => HuxBadgeVariant.primary,
      'closed' => HuxBadgeVariant.error,
      'approved' => HuxBadgeVariant.success,
      _ => HuxBadgeVariant.secondary,
    };
  }
}
