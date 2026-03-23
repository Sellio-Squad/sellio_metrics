
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/utils/date_utils.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/enums/pr_size_category.dart';
import 'package:sellio_metrics/domain/enums/pr_type.dart';
import 'package:sellio_metrics/domain/services/pr_analysis_service.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_info_chip.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_diff_stats_chip.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_type_badge.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_timeline_summary.dart';

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
    final scheme = context.colors;
    final sizeCategory = PrAnalysisService.categorizeSize(pr);
    final isStarred = PrAnalysisService.isStarred(pr);
    final hasImages = PrAnalysisService.hasImages(pr);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go('/prs/${pr.prNumber}'),
        child: AnimatedContainer(
          duration: AnimationConstants.hoverDuration,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          transform: _isHovered
              ? (Matrix4.identity()
                ..scaleByDouble(
                  AnimationConstants.hoverScale,
                  AnimationConstants.hoverScale,
                  1.0,
                  1.0,
                ))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: scheme.surfaceLow,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _isHovered
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.stroke,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SAvatar(
                name: pr.creator.login,
                imageUrl: pr.creator.avatarUrl.isNotEmpty
                    ? pr.creator.avatarUrl
                    : null,
                size: SAvatarSize.small,
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
                        color: scheme.title,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        PrInfoChip(text: '#${pr.prNumber}'),
                        if (pr.repoName.isNotEmpty)
                          PrInfoChip(
                            text: pr.repoName,
                            icon: Icons.source_outlined,
                          ),
                        PrInfoChip(
                          text: pr.creator.login,
                          icon: Icons.person_outline,
                        ),
                        PrInfoChip(
                          text: formatRelativeTime(pr.openedAt),
                          icon: Icons.schedule,
                        ),
                        PrDiffStatsChip(
                          additions: pr.diffStats.additions,
                          deletions: pr.diffStats.deletions,
                          changedFiles: pr.diffStats.changedFiles,
                        ),
                        PrInfoChip(
                          text:
                              '${pr.approvals.length} / ${pr.requiredApprovals} approvals',
                          icon: Icons.check_circle_outline,
                        ),
                        if (pr.firstApprovedAt != null)
                          PrInfoChip(
                            text:
                                '1st approval ${formatRelativeTime(pr.firstApprovedAt!)}',
                            icon: Icons.thumb_up_alt_outlined,
                          ),
                        if (pr.requiredApprovalsMetAt != null)
                          PrInfoChip(
                            text:
                                'All approvals ${formatRelativeTime(pr.requiredApprovalsMetAt!)}',
                            icon: Icons.done_all_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrTimelineSummary(pr: pr),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PrTypeBadge(prType: prType),
                  const SizedBox(height: AppSpacing.xs),
                  SBadge(
                    label: pr.status.toUpperCase(),
                    variant: _getBadgeVariant(pr.status),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // ─── Inline Indicators ─────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SizePill(category: sizeCategory),
                      if (isStarred) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ] else if (hasImages) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.image_outlined,
                          color: scheme.hint,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _isHovered ? scheme.primary : scheme.hint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  SBadgeVariant _getBadgeVariant(String status) {
    return switch (status) {
      PrStatus.merged => SBadgeVariant.primary,
      PrStatus.closed => SBadgeVariant.error,
      PrStatus.approved => SBadgeVariant.success,
      _ => SBadgeVariant.secondary,
    };
  }
}

class _SizePill extends StatelessWidget {
  final PrSizeCategory category;

  const _SizePill({required this.category});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = switch (category) {
      PrSizeCategory.xs => scheme.green,
      PrSizeCategory.s => scheme.green,
      PrSizeCategory.m => SellioColors.amber,
      PrSizeCategory.l => scheme.red,
      PrSizeCategory.xl => scheme.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        category.label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}
