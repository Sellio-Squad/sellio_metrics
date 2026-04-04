import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/providers/issues_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/widgets/issues_summary_section.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/widgets/issues_insights_section.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/widgets/issues_filter_bar.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/widgets/issues_table.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart'
    show DataLoadingStatus;
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/widgets/common/error_screen.dart';

class OpenIssuesPage extends StatefulWidget {
  const OpenIssuesPage({super.key});

  @override
  State<OpenIssuesPage> createState() => _OpenIssuesPageState();
}

class _OpenIssuesPageState extends State<OpenIssuesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<IssuesProvider>().loadIssues();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IssuesProvider>(
      builder: (context, provider, _) {
        // Loading
        if (provider.status == DataLoadingStatus.loading && provider.allIssues.isEmpty) {
          return const LoadingScreen();
        }
        // Error
        if (provider.status == DataLoadingStatus.error && provider.allIssues.isEmpty) {
          return ErrorScreen(onRetry: () => provider.loadIssues());
        }

        final metrics = provider.summaryMetrics;
        final insights = provider.scrumInsights;
        final filtered = provider.filteredIssues;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── Page header ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _PageHeader(
                        totalCount: metrics.total,
                        onRefresh: provider.refresh,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // ── KPI Summary ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: IssuesSummarySection(metrics: metrics),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // ── Scrum Insights ───────────────────────────────────
                    if (insights.isNotEmpty)
                      SliverToBoxAdapter(
                        child: IssuesInsightsSection(insights: insights),
                      ),
                    if (insights.isNotEmpty)
                      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // ── Filter Bar ───────────────────────────────────────
                    SliverToBoxAdapter(
                      child: IssuesFilterBar(
                        availableRepos: provider.availableRepos,
                        availableAssignees: provider.availableAssignees,
                        availableLabels: provider.availableLabels,
                        selectedRepo: provider.selectedRepo,
                        selectedAssignee: provider.selectedAssignee,
                        selectedLabel: provider.selectedLabel,
                        searchTerm: provider.searchTerm,
                        onSearch: provider.setSearchTerm,
                        onRepoChanged: provider.setRepoFilter,
                        onAssigneeChanged: provider.setAssigneeFilter,
                        onLabelChanged: provider.setLabelFilter,
                        onClearFilters: provider.clearFilters,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

                    // ── Result count ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: _ResultsHeader(count: filtered.length, total: metrics.total),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

                    // ── Issues Table / Cards ─────────────────────────────
                    SliverToBoxAdapter(
                      child: IssuesTable(issues: filtered),
                    ),

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Page Header ─────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int totalCount;
  final VoidCallback onRefresh;

  const _PageHeader({required this.totalCount, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Issues',
              style: AppTypography.heading.copyWith(color: scheme.title),
            ),
            const SizedBox(height: 2),
            Text(
              '$totalCount open ticket${totalCount != 1 ? 's' : ''} across the organization',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: Icon(LucideIcons.refreshCw, size: 18, color: scheme.hint),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

// ─── Results Header ──────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  final int count;
  final int total;

  const _ResultsHeader({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isFiltered = count != total;
    return Text(
      isFiltered
          ? 'Showing $count of $total issues'
          : '$count issue${count != 1 ? 's' : ''}',
      style: AppTypography.caption.copyWith(color: scheme.hint),
    );
  }
}
