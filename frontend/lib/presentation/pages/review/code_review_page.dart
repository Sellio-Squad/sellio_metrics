import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';
import 'package:sellio_metrics/presentation/pages/review/providers/review_provider.dart';

class CodeReviewPage extends StatefulWidget {
  const CodeReviewPage({super.key});

  @override
  State<CodeReviewPage> createState() => _CodeReviewPageState();
}

class _CodeReviewPageState extends State<CodeReviewPage>
    with SingleTickerProviderStateMixin {
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _prController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final provider = context.read<ReviewProvider>();
    _ownerController.text = provider.selectedOwner;
    _repoController.text = provider.selectedRepo;
    _prController.text = provider.prNumber.toString();
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _prController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          _ReviewHeader(),
          Expanded(
            child: Consumer<ReviewProvider>(
              builder: (context, provider, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Panel — Input Form
                    _InputPanel(
                      ownerController: _ownerController,
                      repoController: _repoController,
                      prController: _prController,
                      provider: provider,
                      tabController: _tabController,
                    ),
                    // Right Panel — Results
                    Expanded(
                      child: _ResultsPanel(
                        provider: provider,
                        tabController: _tabController,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════

class _ReviewHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(
          bottom: BorderSide(color: scheme.stroke, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: SellioColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              LucideIcons.searchCode,
              size: 18,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Code Review',
                style: AppTypography.subtitle.copyWith(
                  color: scheme.title,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                'Powered by Gemini · Production-level analysis',
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// INPUT PANEL (Left side)
// ═══════════════════════════════════════════════════════

class _InputPanel extends StatelessWidget {
  final TextEditingController ownerController;
  final TextEditingController repoController;
  final TextEditingController prController;
  final ReviewProvider provider;
  final TabController tabController;

  const _InputPanel({
    required this.ownerController,
    required this.repoController,
    required this.prController,
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
          // ─── Form card ────────────────────────────────
          _SectionLabel('Pull Request', scheme),
          const SizedBox(height: AppSpacing.sm),
          _FieldLabel('Organization / Owner', scheme),
          const SizedBox(height: AppSpacing.xs),
          _StyledTextField(
            controller: ownerController,
            hint: 'e.g. Sellio-Squad',
            icon: LucideIcons.building2,
            onChanged: (v) => provider.setOwner(v),
          ),
          const SizedBox(height: AppSpacing.md),
          _FieldLabel('Repository', scheme),
          const SizedBox(height: AppSpacing.xs),
          _StyledTextField(
            controller: repoController,
            hint: 'e.g. sellio_mobile',
            icon: LucideIcons.gitBranch,
            onChanged: (v) => provider.setRepo(v),
          ),
          const SizedBox(height: AppSpacing.md),
          _FieldLabel('PR Number', scheme),
          const SizedBox(height: AppSpacing.xs),
          _StyledTextField(
            controller: prController,
            hint: 'e.g. 42',
            icon: LucideIcons.gitPullRequest,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) provider.setPrNumber(n);
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Submit button ────────────────────────────
          _AnalyzeButton(provider: provider, tabController: tabController),

          // ─── Stats (if result available) ────────────
          if (provider.hasResult) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionLabel('Results', scheme),
            const SizedBox(height: AppSpacing.sm),
            _StatsWidget(review: provider.review!),
          ],

          // ─── Reset ────────────────────────────────────
          if (!provider.isLoading && provider.status != ReviewStatus.idle) ...[
            const SizedBox(height: AppSpacing.lg),
            _ResetButton(provider: provider),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final SellioColorScheme scheme;
  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.overline.copyWith(
        color: scheme.hint,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final SellioColorScheme scheme;
  const _FieldLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: scheme.body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.stroke, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(icon, size: 15, color: scheme.hint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(
                color: scheme.title,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.body.copyWith(
                  color: scheme.hint,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  final ReviewProvider provider;
  final TabController tabController;
  const _AnalyzeButton({required this.provider, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: provider.isLoading ? scheme.disabled : scheme.primary,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: provider.isLoading
              ? null
              : () {
                  provider.runReview();
                  tabController.animateTo(0);
                },
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: provider.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Analyzing...',
                        style: AppTypography.body.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles,
                          size: 16, color: scheme.onPrimary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Analyze with AI',
                        style: AppTypography.body.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatsWidget extends StatelessWidget {
  final ReviewEntity review;
  const _StatsWidget({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Column(
      children: [
        _StatRow('Total Issues', '${review.totalIssues}',
            LucideIcons.alertTriangle, scheme.secondary, scheme),
        _StatRow('Critical', '${review.criticalCount}', LucideIcons.alertOctagon,
            scheme.red, scheme),
        _StatRow(
            'Bugs',
            '${review.bugs.length}',
            LucideIcons.bug,
            review.bugs.isEmpty ? scheme.green : scheme.red,
            scheme),
        _StatRow(
            'Security',
            '${review.security.length}',
            LucideIcons.shieldAlert,
            review.security.isEmpty ? scheme.green : scheme.red,
            scheme),
        _StatRow(
            'Performance',
            '${review.performance.length}',
            LucideIcons.zap,
            review.performance.isEmpty ? scheme.green : scheme.secondary,
            scheme),
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
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: scheme.body,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
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
      label: Text(
        'Clear & Reset',
        style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// RESULTS PANEL (Right side)
// ═══════════════════════════════════════════════════════

class _ResultsPanel extends StatelessWidget {
  final ReviewProvider provider;
  final TabController tabController;

  const _ResultsPanel({
    required this.provider,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) return _LoadingView();
    if (provider.hasError) return _ErrorView(message: provider.errorMessage);
    if (!provider.hasResult) return _EmptyView();
    return _ReviewResultView(
      review: provider.review!,
      tabController: tabController,
    );
  }
}

class _LoadingView extends StatelessWidget {
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
                  strokeWidth: 2.5,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Analyzing PR...',
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Gemini AI is reviewing your code',
            style: AppTypography.body.copyWith(
              color: scheme.hint,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This may take 10–20 seconds',
            style: AppTypography.caption.copyWith(
              color: scheme.hint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

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
                color: scheme.redVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  Center(child: Icon(LucideIcons.alertOctagon, size: 32, color: scheme.red)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Review Failed',
              style: AppTypography.subtitle.copyWith(
                color: scheme.title,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
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
              child: Icon(
                LucideIcons.searchCode,
                size: 40,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Ready for Review',
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter repo details and PR number,\nthen click "Analyze with AI"',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 14),
          ),
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: scheme.body,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// REVIEW RESULT VIEW
// ═══════════════════════════════════════════════════════

class _ReviewResultView extends StatelessWidget {
  final ReviewEntity review;
  final TabController tabController;

  const _ReviewResultView({
    required this.review,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      children: [
        // ─── PR Summary Header ─────────────────────────────────
        _PrSummaryHeader(review: review),

        // ─── Tabs ──────────────────────────────────────────────
        Container(
          color: scheme.surfaceLow,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: AppTypography.body.copyWith(fontSize: 13),
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.hint,
            indicatorColor: scheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: scheme.stroke,
            tabs: [
              _ReviewTab(
                  'Bugs', review.bugs.length, LucideIcons.bug, scheme.red),
              _ReviewTab('Best Practices', review.bestPractices.length,
                  LucideIcons.checkCircle, SellioColors.blue),
              _ReviewTab('Security', review.security.length,
                  LucideIcons.shieldAlert, scheme.secondary),
              _ReviewTab('Performance', review.performance.length,
                  LucideIcons.zap, SellioColors.purple),
            ],
          ),
        ),

        // ─── Tab Content ───────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _FindingsList(findings: review.bugs, emptyLabel: 'No bugs found'),
              _FindingsList(
                  findings: review.bestPractices,
                  emptyLabel: 'No best practice issues'),
              _FindingsList(
                  findings: review.security,
                  emptyLabel: 'No security issues found'),
              _FindingsList(
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
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// PR SUMMARY HEADER
// ═══════════════════════════════════════════════════════

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
        border: Border(bottom: BorderSide(color: scheme.stroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PR title + badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${pr.number}',
                  style: AppTypography.caption.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pr.title,
                  style: AppTypography.subtitle.copyWith(
                    color: scheme.title,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Overall health indicator
              _HealthBadge(review: review),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Author + stats
          Row(
            children: [
              Icon(LucideIcons.user, size: 12, color: scheme.hint),
              const SizedBox(width: 4),
              Text(pr.author,
                  style: AppTypography.caption
                      .copyWith(color: scheme.hint, fontSize: 11)),
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
                  style: AppTypography.caption
                      .copyWith(color: scheme.hint, fontSize: 11)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // AI Summary
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
                  child: Text(
                    review.prSummary,
                    style: AppTypography.body.copyWith(
                      color: scheme.body,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
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
    Color color;
    IconData icon;
    String label;

    if (review.criticalCount > 0) {
      color = scheme.red;
      icon = LucideIcons.alertOctagon;
      label = 'Needs Work';
    } else if (review.totalIssues > 0) {
      color = scheme.secondary;
      icon = LucideIcons.alertTriangle;
      label = 'Minor Issues';
    } else {
      color = scheme.green;
      icon = LucideIcons.checkCircle2;
      label = 'Looks Good';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// FINDINGS LIST
// ═══════════════════════════════════════════════════════

class _FindingsList extends StatelessWidget {
  final List<ReviewFindingEntity> findings;
  final String emptyLabel;

  const _FindingsList({required this.findings, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return _EmptyCategoryView(label: emptyLabel);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: findings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) => _FindingCard(finding: findings[index]),
    );
  }
}

class _EmptyCategoryView extends StatelessWidget {
  final String label;
  const _EmptyCategoryView({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.checkCircle2, size: 40, color: scheme.green),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: scheme.hint,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// FINDING CARD
// ═══════════════════════════════════════════════════════

class _FindingCard extends StatefulWidget {
  final ReviewFindingEntity finding;
  const _FindingCard({required this.finding});

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final f = widget.finding;
    final config = _severityConfig(f.severity, scheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: config.color.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Card header ─────────────────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
                bottom: _expanded ? Radius.zero : Radius.circular(AppRadius.md)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity indicator
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: config.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Severity badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: config.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(config.icon,
                                      size: 10, color: config.color),
                                  const SizedBox(width: 3),
                                  Text(
                                    f.severity.label.toUpperCase(),
                                    style: AppTypography.overline.copyWith(
                                      color: config.color,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // File path
                            Expanded(
                              child: Text(
                                _shortPath(f.file),
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (f.line != null)
                              Text(
                                ':${f.line}',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          f.title,
                          style: AppTypography.subtitle.copyWith(
                            color: scheme.title,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: scheme.hint,
                  ),
                ],
              ),
            ),
          ),

          // ─── Expandable body ──────────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: scheme.stroke),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.description,
                    style: AppTypography.body.copyWith(
                      color: scheme.body,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  if (f.suggestion != null && f.suggestion!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: scheme.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.lightbulb,
                              size: 14, color: scheme.green),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suggestion',
                                  style: AppTypography.caption.copyWith(
                                    color: scheme.green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  f.suggestion!,
                                  style: AppTypography.body.copyWith(
                                    color: scheme.body,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shortPath(String path) {
    final parts = path.split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  ({Color color, IconData icon}) _severityConfig(
      ReviewSeverity severity, SellioColorScheme scheme) {
    switch (severity) {
      case ReviewSeverity.critical:
        return (color: scheme.red, icon: LucideIcons.alertOctagon);
      case ReviewSeverity.warning:
        return (color: scheme.secondary, icon: LucideIcons.alertTriangle);
      case ReviewSeverity.info:
        return (color: SellioColors.blue, icon: LucideIcons.info);
    }
  }
}
