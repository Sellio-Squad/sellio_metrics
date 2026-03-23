/// PR Details Header
///
/// Displays the PR title, badges, creator info, and size category.

import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/utils/date_utils.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/enums/pr_size_category.dart';
import 'package:sellio_metrics/domain/enums/pr_type.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_type_badge.dart';

class PrDetailsHeader extends StatelessWidget {
  final PrEntity pr;
  final PrSizeCategory sizeCategory;
  final bool isStarred;

  const PrDetailsHeader({
    super.key,
    required this.pr,
    required this.sizeCategory,
    required this.isStarred,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final prType = PrType.fromTitle(pr.title);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Title Row ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SAvatar(
                name: pr.creator.login,
                imageUrl:
                    pr.creator.avatarUrl.isNotEmpty ? pr.creator.avatarUrl : null,
                size: SAvatarSize.medium,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pr.title,
                      style: AppTypography.title.copyWith(
                        color: scheme.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${pr.creator.login} opened ${formatRelativeTime(pr.openedAt)}',
                      style: AppTypography.body.copyWith(
                        color: scheme.hint,
                      ),
                    ),
                  ],
                ),
              ),
              if (isStarred) ...[
                const SizedBox(width: AppSpacing.sm),
                _StarBadge(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ─── Badges Row ────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SBadge(
                label: '#${pr.prNumber}',
                variant: SBadgeVariant.secondary,
              ),
              if (pr.repoName.isNotEmpty)
                SBadge(
                  label: pr.repoName,
                  variant: SBadgeVariant.secondary,
                ),
              PrTypeBadge(prType: prType),
              SBadge(
                label: pr.status.toUpperCase(),
                variant: _statusVariant(pr.status),
              ),
              _SizeBadge(sizeCategory: sizeCategory),
              if (pr.draft)
                SBadge(
                  label: 'DRAFT',
                  variant: SBadgeVariant.secondary,
                ),
              SBadge(
                label:
                    '${pr.approvals.length}/${pr.requiredApprovals} approvals',
                variant: pr.approvals.length >= pr.requiredApprovals
                    ? SBadgeVariant.success
                    : SBadgeVariant.secondary,
              ),
            ],
          ),

          // ─── Branch Info ───────────────────────────
          if (pr.headRef.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(LucideIcons.gitBranch, size: 14, color: scheme.hint),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${pr.headRef} → ${pr.baseRef}',
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          // ─── Labels ────────────────────────────────
          if (pr.labels.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: pr.labels
                  .map((label) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          label,
                          style: AppTypography.caption.copyWith(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  SBadgeVariant _statusVariant(String status) {
    return switch (status) {
      'merged' => SBadgeVariant.primary,
      'closed' => SBadgeVariant.error,
      'approved' => SBadgeVariant.success,
      _ => SBadgeVariant.secondary,
    };
  }
}

class _SizeBadge extends StatelessWidget {
  final PrSizeCategory sizeCategory;

  const _SizeBadge({required this.sizeCategory});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = switch (sizeCategory) {
      PrSizeCategory.xs => scheme.green,
      PrSizeCategory.s => scheme.green,
      PrSizeCategory.m => SellioColors.amber,
      PrSizeCategory.l => scheme.red,
      PrSizeCategory.xl => scheme.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Size: ${sizeCategory.label}',
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _StarBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            'Video',
            style: AppTypography.caption.copyWith(
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
