library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/layout_constants.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../design_system/design_system.dart';
import '../../../../domain/entities/pr_entity.dart';
import '../../../../domain/enums/pr_type.dart';
import 'pr_info_chip.dart';
import 'pr_diff_stats_chip.dart';
import 'pr_type_badge.dart';
import 'pr_timeline_summary.dart';
import 'pr_expanded_details.dart';

class PrListTile extends StatefulWidget {
  final PrEntity pr;

  const PrListTile({super.key, required this.pr});

  @override
  State<PrListTile> createState() => _PrListTileState();
}

class _PrListTileState extends State<PrListTile> {
  bool _isHovered = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pr = widget.pr;
    final prType = PrType.fromTitle(pr.title);
    final scheme = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _openPrUrl,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => _isExpanded = !_isExpanded);
                        },
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: AnimationConstants.hoverDuration,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: scheme.hint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                PrExpandedDetails(pr: pr),
              ],
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

  SBadgeVariant _getBadgeVariant(String status) {
    return switch (status) {
      PrStatus.merged => SBadgeVariant.primary,
      PrStatus.closed => SBadgeVariant.error,
      PrStatus.approved => SBadgeVariant.success,
      _ => SBadgeVariant.secondary,
    };
  }
}
