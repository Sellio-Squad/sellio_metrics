import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/presentation/pages/review/providers/review_provider.dart';
import 'package:sellio_metrics/presentation/pages/review/widgets/review_finding_card.dart';

/// Right panel — shows loading / error / empty / full review result
class ReviewResultsPanel extends StatelessWidget {
  final ReviewProvider provider;
  final TabController tabController;

  const ReviewResultsPanel({
    super.key,
    required this.provider,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) return const _LoadingView();
    if (provider.hasError) return _ErrorView(message: provider.errorMessage);
    if (!provider.hasResult) return const _EmptyView();
    return _ReviewResultView(
        review: provider.review!, tabController: tabController);
  }
}

// ─── Loading ──────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: SellioColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: scheme.onPrimary)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Analyzing PR…',
              style: AppTypography.subtitle.copyWith(
                  color: scheme.title, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          Text('Gemini AI is reviewing your code',
              style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          Text('This may take 10–20 seconds',
              style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: scheme.redVariant, borderRadius: BorderRadius.circular(20)),
              child: Center(
                  child: Icon(LucideIcons.alertOctagon, size: 32, color: scheme.red)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Review Failed',
                style: AppTypography.subtitle.copyWith(
                    color: scheme.title, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / idle ─────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryVariant,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.stroke),
            ),
            child: Center(
                child: Icon(LucideIcons.searchCode, size: 40, color: scheme.primary)),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Ready for Review',
              style: AppTypography.subtitle.copyWith(
                  color: scheme.title, fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: AppSpacing.sm),
          Text('Select a repository and PR,\nthen click "Analyze with AI"',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 14)),
          const SizedBox(height: AppSpacing.xl),
          _FeatureChip(icon: LucideIcons.bug, label: 'Bugs & Logic Errors'),
          const SizedBox(height: AppSpacing.sm),
          _FeatureChip(icon: LucideIcons.shieldAlert, label: 'Security Issues'),
          const SizedBox(height: AppSpacing.sm),
          _FeatureChip(icon: LucideIcons.zap, label: 'Performance Concerns'),
          const SizedBox(height: AppSpacing.sm),
          _FeatureChip(icon: LucideIcons.checkCircle, label: 'Best Practices'),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.stroke)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(label,
              style: AppTypography.body.copyWith(
                  color: scheme.body, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Full review view ─────────────────────────────────────────

class _ReviewResultView extends StatelessWidget {
  final ReviewEntity review;
  final TabController tabController;
  const _ReviewResultView({required this.review, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Column(
      children: [
        _PrSummaryHeader(review: review),
        Container(
          color: scheme.surfaceLow,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle:
                AppTypography.body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: AppTypography.body.copyWith(fontSize: 13),
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.hint,
            indicatorColor: scheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: scheme.stroke,
            tabs: [
              _ReviewTab('Bugs', review.bugs.length,
                  LucideIcons.bug, scheme.red),
              _ReviewTab('Best Practices', review.bestPractices.length,
                  LucideIcons.checkCircle, SellioColors.blue),
              _ReviewTab('Security', review.security.length,
                  LucideIcons.shieldAlert, scheme.secondary),
              _ReviewTab('Performance', review.performance.length,
                  LucideIcons.zap, SellioColors.purple),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              FindingsList(findings: review.bugs, emptyLabel: 'No bugs found'),
              FindingsList(
                  findings: review.bestPractices,
                  emptyLabel: 'No best practice issues'),
              FindingsList(
                  findings: review.security,
                  emptyLabel: 'No security issues found'),
              FindingsList(
                  findings: review.performance,
                  emptyLabel: 'No performance issues found'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewTab extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _ReviewTab(this.label, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── PR summary header ────────────────────────────────────────

class _PrSummaryHeader extends StatelessWidget {
  final ReviewEntity review;
  const _PrSummaryHeader({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final pr = review.pr;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: scheme.surfaceLow,
          border: Border(bottom: BorderSide(color: scheme.stroke))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: scheme.primaryVariant,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('#${pr.number}',
                    style: AppTypography.caption.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(pr.title,
                    style: AppTypography.subtitle.copyWith(
                        color: scheme.title,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              // Cache badge
              if (review.fromCache) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: scheme.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.green.withValues(alpha: 0.3))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.database, size: 10, color: scheme.green),
                      const SizedBox(width: 4),
                      Text('Cached',
                          style: AppTypography.caption.copyWith(
                              color: scheme.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              _HealthBadge(review: review),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(LucideIcons.user, size: 12, color: scheme.hint),
              const SizedBox(width: 4),
              Text(pr.author,
                  style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
              const SizedBox(width: AppSpacing.md),
              Icon(LucideIcons.filePlus2, size: 12, color: scheme.green),
              const SizedBox(width: 4),
              Text('+${pr.additions}',
                  style: AppTypography.caption.copyWith(
                      color: scheme.green, fontWeight: FontWeight.w600, fontSize: 11)),
              const SizedBox(width: AppSpacing.md),
              Icon(LucideIcons.fileMinus2, size: 12, color: scheme.red),
              const SizedBox(width: 4),
              Text('-${pr.deletions}',
                  style: AppTypography.caption.copyWith(
                      color: scheme.red, fontWeight: FontWeight.w600, fontSize: 11)),
              const SizedBox(width: AppSpacing.md),
              Icon(LucideIcons.files, size: 12, color: scheme.hint),
              const SizedBox(width: 4),
              Text('${pr.changedFiles} files',
                  style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
              // Review meta
              if (review.reviewMeta != null) ...[
                const SizedBox(width: AppSpacing.md),
                Icon(LucideIcons.filter, size: 12, color: scheme.hint),
                const SizedBox(width: 4),
                Text(
                    '${review.reviewMeta!.filesReviewed}/${review.reviewMeta!.totalFiles} reviewed',
                    style: AppTypography.caption
                        .copyWith(color: scheme.hint, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: scheme.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.sparkles, size: 14, color: scheme.secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(review.prSummary,
                      style: AppTypography.body
                          .copyWith(color: scheme.body, fontSize: 13, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final ReviewEntity review;
  const _HealthBadge({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    late Color color;
    late IconData icon;
    late String label;

    if (review.criticalCount > 0) {
      color = scheme.red; icon = LucideIcons.alertOctagon; label = 'Needs Work';
    } else if (review.totalIssues > 0) {
      color = scheme.secondary; icon = LucideIcons.alertTriangle; label = 'Minor Issues';
    } else {
      color = scheme.green; icon = LucideIcons.checkCircle2; label = 'Looks Good';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTypography.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }
}
