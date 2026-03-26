import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/presentation/pages/review/providers/review_provider.dart';

/// Left 300px panel — repo/PR dropdowns, analyze button, stats
class ReviewSelectionPanel extends StatelessWidget {
  final ReviewProvider provider;
  final TabController tabController;

  const ReviewSelectionPanel({
    super.key,
    required this.provider,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(right: BorderSide(color: scheme.stroke, width: 1)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SectionLabel('Select Target', scheme),
          const SizedBox(height: AppSpacing.md),

          _DropdownLabel('Repository', scheme),
          const SizedBox(height: AppSpacing.xs),
          provider.loadingMeta
              ? _LoadingDropdown(scheme: scheme)
              : _RepoDropdown(provider: provider),

          const SizedBox(height: AppSpacing.lg),

          _DropdownLabel('Pull Request', scheme),
          const SizedBox(height: AppSpacing.xs),
          provider.loadingMeta
              ? _LoadingDropdown(scheme: scheme)
              : _PrDropdown(provider: provider),

          const SizedBox(height: AppSpacing.xl),

          if (provider.selectedSlimPr != null) ...[
            _SelectedPrCard(pr: provider.selectedSlimPr!, scheme: scheme),
            const SizedBox(height: AppSpacing.xl),
          ],

          _AnalyzeButton(provider: provider, tabController: tabController),

          if (provider.hasResult) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Results', scheme),
            const SizedBox(height: AppSpacing.sm),
            _StatsWidget(review: provider.review!),
          ],

          if (!provider.isLoading && provider.status != ReviewStatus.idle) ...[
            const SizedBox(height: AppSpacing.lg),
            _ResetButton(provider: provider),
          ],
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final SellioColorScheme scheme;
  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.overline.copyWith(
            color: scheme.hint,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700),
      );
}

class _DropdownLabel extends StatelessWidget {
  final String text;
  final SellioColorScheme scheme;
  const _DropdownLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTypography.caption.copyWith(
            color: scheme.body, fontSize: 12, fontWeight: FontWeight.w500),
      );
}

// ─── Loading placeholder ──────────────────────────────────────

class _LoadingDropdown extends StatelessWidget {
  final SellioColorScheme scheme;
  const _LoadingDropdown({required this.scheme});

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: scheme.stroke),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.hint),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Loading…',
                style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13)),
          ],
        ),
      );
}

// ─── Repo dropdown ────────────────────────────────────────────

class _RepoDropdown extends StatelessWidget {
  final ReviewProvider provider;
  const _RepoDropdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    if (provider.repos.isEmpty) {
      return _EmptyDropdownHint(
          icon: LucideIcons.gitBranch, label: 'No repositories found', scheme: scheme);
    }
    return _StyledDropdown<RepoInfo>(
      value: provider.selectedRepo,
      icon: LucideIcons.gitBranch,
      hint: 'Select a repository',
      items: provider.repos,
      labelBuilder: (r) => r.name,
      onChanged: provider.selectRepo,
      scheme: scheme,
    );
  }
}

// ─── PR dropdown ──────────────────────────────────────────────

class _PrDropdown extends StatelessWidget {
  final ReviewProvider provider;
  const _PrDropdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final prs = provider.prsForSelectedRepo;

    if (provider.selectedRepo == null) {
      return _EmptyDropdownHint(
          icon: LucideIcons.gitPullRequest, label: 'Select a repo first', scheme: scheme);
    }
    if (prs.isEmpty) {
      return _EmptyDropdownHint(
          icon: LucideIcons.gitPullRequest,
          label: 'No open PRs in this repo',
          scheme: scheme);
    }

    final selected = provider.selectedSlimPr;
    final validSelected =
        selected != null && prs.any((p) => p.prNumber == selected.prNumber)
            ? selected
            : null;

    return _StyledDropdown<SlimPrEntry>(
      value: validSelected,
      icon: LucideIcons.gitPullRequest,
      hint: 'Select a pull request',
      items: prs,
      labelBuilder: (pr) => pr.displayLabel,
      onChanged: provider.selectSlimPr,
      scheme: scheme,
    );
  }
}

// ─── Generic styled dropdown ──────────────────────────────────

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final IconData icon;
  final String hint;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;
  final SellioColorScheme scheme;

  const _StyledDropdown({
    required this.value,
    required this.icon,
    required this.hint,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.hint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              hint: Text(hint,
                  style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13)),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              icon: Icon(LucideIcons.chevronDown, size: 15, color: scheme.hint),
              dropdownColor: scheme.surfaceLow,
              style: AppTypography.body.copyWith(color: scheme.title, fontSize: 13),
              items: items.map((item) {
                final label = labelBuilder(item);
                return DropdownMenuItem<T>(
                  value: item,
                  child: Tooltip(
                    message: label,
                    child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
                  ),
                );
              }).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDropdownHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final SellioColorScheme scheme;
  const _EmptyDropdownHint(
      {required this.icon, required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: scheme.stroke),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 15, color: scheme.disabled),
            const SizedBox(width: AppSpacing.sm),
            Text(label,
                style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13)),
          ],
        ),
      );
}

// ─── Selected PR card ─────────────────────────────────────────

class _SelectedPrCard extends StatelessWidget {
  final SlimPrEntry pr;
  final SellioColorScheme scheme;
  const _SelectedPrCard({required this.pr, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('#${pr.prNumber}',
                    style: AppTypography.caption.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(pr.title,
                    style: AppTypography.body.copyWith(
                        color: scheme.title,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(LucideIcons.user, size: 11, color: scheme.hint),
              const SizedBox(width: 3),
              Text(pr.author,
                  style: AppTypography.caption
                      .copyWith(color: scheme.hint, fontSize: 11)),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.filePlus2, size: 11, color: scheme.green),
              const SizedBox(width: 3),
              Text('+${pr.additions}',
                  style: AppTypography.caption.copyWith(
                      color: scheme.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.fileMinus2, size: 11, color: scheme.red),
              const SizedBox(width: 3),
              Text('-${pr.deletions}',
                  style: AppTypography.caption.copyWith(
                      color: scheme.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Analyze button ───────────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  final ReviewProvider provider;
  final TabController tabController;
  const _AnalyzeButton({required this.provider, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final enabled = provider.canReview;
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      color: enabled && !provider.isLoading ? scheme.primary : scheme.disabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: (provider.isLoading || !enabled)
            ? null
            : () {
                provider.runReview();
                tabController.animateTo(0);
              },
        child: SizedBox(
          height: 44,
          child: Center(
            child: provider.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary)),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Analyzing…',
                          style: AppTypography.body.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles, size: 16, color: scheme.onPrimary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Analyze with AI',
                          style: AppTypography.body.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Stats widget ─────────────────────────────────────────────

class _StatsWidget extends StatelessWidget {
  final ReviewEntity review;
  const _StatsWidget({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Column(
      children: [
        _StatRow('Issues', '${review.totalIssues}',
            LucideIcons.alertTriangle, scheme.secondary, scheme),
        _StatRow('Critical', '${review.criticalCount}',
            LucideIcons.alertOctagon, scheme.red, scheme),
        _StatRow('Bugs', '${review.bugs.length}', LucideIcons.bug,
            review.bugs.isEmpty ? scheme.green : scheme.red, scheme),
        _StatRow('Security', '${review.security.length}',
            LucideIcons.shieldAlert,
            review.security.isEmpty ? scheme.green : scheme.red, scheme),
        _StatRow('Performance', '${review.performance.length}',
            LucideIcons.zap,
            review.performance.isEmpty ? scheme.green : scheme.secondary, scheme),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final SellioColorScheme scheme;
  const _StatRow(this.label, this.value, this.icon, this.color, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(label,
                  style: AppTypography.caption
                      .copyWith(color: scheme.body, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text(value,
                style: AppTypography.caption.copyWith(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final ReviewProvider provider;
  const _ResetButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TextButton.icon(
      onPressed: provider.reset,
      icon: Icon(LucideIcons.rotateCcw, size: 13, color: scheme.hint),
      label: Text('Clear Results',
          style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 12)),
    );
  }
}
