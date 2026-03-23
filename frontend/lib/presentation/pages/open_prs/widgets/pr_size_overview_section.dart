/// PR Size Overview Section
///
/// Top-level section on the Open PRs page (like bottlenecks).
/// Highlights large PRs (L/XL) with size hints and split suggestions.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/enums/pr_size_category.dart';
import 'package:sellio_metrics/domain/services/pr_analysis_service.dart';
import 'package:sellio_metrics/presentation/widgets/section_header.dart';

class PrSizeOverviewSection extends StatelessWidget {
  final List<PrEntity> prs;

  const PrSizeOverviewSection({super.key, required this.prs});

  @override
  Widget build(BuildContext context) {
    final largePrs = prs
        .where((pr) => PrAnalysisService.categorizeSize(pr).isLarge)
        .toList();

    if (largePrs.isEmpty) return const SizedBox.shrink();

    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: LucideIcons.alertTriangle,
          title: 'Large PRs — Consider Splitting',
        ),
        const SizedBox(height: AppSpacing.md),
        ...largePrs.map(
          (pr) => _LargePrItem(pr: pr, scheme: scheme),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _LargePrItem extends StatefulWidget {
  final PrEntity pr;
  final dynamic scheme;

  const _LargePrItem({required this.pr, required this.scheme});

  @override
  State<_LargePrItem> createState() => _LargePrItemState();
}

class _LargePrItemState extends State<_LargePrItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final pr = widget.pr;
    final category = PrAnalysisService.categorizeSize(pr);
    final isXl = category == PrSizeCategory.xl;
    final accentColor = isXl ? scheme.red : SellioColors.amber;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go('/prs/${pr.prNumber}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: _isHovered ? 0.08 : 0.04),
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: accentColor.withValues(alpha: _isHovered ? 0.4 : 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isXl
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: accentColor,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pr.title,
                      style: AppTypography.body.copyWith(
                        color: scheme.title,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${pr.prNumber} · ${pr.creator.login} · +${pr.diffStats.additions} / -${pr.diffStats.deletions} (${pr.diffStats.changedFiles} files)',
                      style: AppTypography.caption.copyWith(
                        color: scheme.hint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.label,
                  style: AppTypography.caption.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
