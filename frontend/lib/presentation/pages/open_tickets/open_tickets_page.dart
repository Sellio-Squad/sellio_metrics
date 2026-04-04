import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/providers/tickets_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/widgets/tickets_summary_section.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/widgets/tickets_insights_section.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/widgets/tickets_filter_bar.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/widgets/tickets_table.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart'
    show DataLoadingStatus;
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/widgets/common/error_screen.dart';

class OpenTicketsPage extends StatefulWidget {
  const OpenTicketsPage({super.key});

  @override
  State<OpenTicketsPage> createState() => _OpenTicketsPageState();
}

class _OpenTicketsPageState extends State<OpenTicketsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TicketsProvider>().loadTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TicketsProvider>(
      builder: (context, provider, _) {
        if (provider.status == DataLoadingStatus.loading && provider.allTickets.isEmpty) {
          return const LoadingScreen();
        }
        if (provider.status == DataLoadingStatus.error && provider.allTickets.isEmpty) {
          return ErrorScreen(onRetry: () => provider.loadTickets());
        }

        final metrics  = provider.summaryMetrics;
        final insights = provider.scrumInsights;
        final filtered = provider.filteredTickets;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(children: [
            Expanded(child: CustomScrollView(slivers: [
              // ── Header ──────────────────────────────────────
              SliverToBoxAdapter(child: _PageHeader(
                metrics: metrics, onRefresh: provider.refresh)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // ── KPI cards ───────────────────────────────────
              SliverToBoxAdapter(child: TicketsSummarySection(metrics: metrics)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // ── Insights ────────────────────────────────────
              if (insights.isNotEmpty) ...[
                SliverToBoxAdapter(child: TicketsInsightsSection(insights: insights)),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              ],

              // ── Filter bar ──────────────────────────────────
              SliverToBoxAdapter(child: TicketsFilterBar(
                sourceFilter:       provider.sourceFilter,
                availableRepos:     provider.availableRepos,
                availableAssignees: provider.availableAssignees,
                availableLabels:    provider.availableLabels,
                selectedRepo:       provider.selectedRepo,
                selectedAssignee:   provider.selectedAssignee,
                selectedLabel:      provider.selectedLabel,
                searchTerm:         provider.searchTerm,
                onSourceChanged:    provider.setSourceFilter,
                onSearch:           provider.setSearchTerm,
                onRepoChanged:      provider.setRepoFilter,
                onAssigneeChanged:  provider.setAssigneeFilter,
                onLabelChanged:     provider.setLabelFilter,
                onClearFilters:     provider.clearFilters,
              )),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

              // ── Result count ────────────────────────────────
              SliverToBoxAdapter(child: _ResultsCount(
                count: filtered.length, total: metrics.total)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

              // ── Table / Cards ────────────────────────────────
              SliverToBoxAdapter(child: TicketsTable(tickets: filtered)),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ])),
          ]),
        );
      },
    );
  }
}

// ─── Page Header ──────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final TicketSummaryMetrics metrics;
  final VoidCallback onRefresh;

  const _PageHeader({required this.metrics, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Open Tickets', style: AppTypography.heading.copyWith(color: scheme.title)),
        const SizedBox(height: 2),
        Text(
          '${metrics.total} open ticket${metrics.total != 1 ? 's' : ''}'
          ' · ${metrics.fromIssues} issues'
          ' · ${metrics.fromProjectItems} project items'
          ' · ${metrics.fromDrafts} drafts',
          style: AppTypography.body.copyWith(color: scheme.hint),
        ),
      ]),
      const Spacer(),
      IconButton(
        icon: Icon(LucideIcons.refreshCw, size: 18, color: scheme.hint),
        onPressed: onRefresh,
        tooltip: 'Refresh',
      ),
    ]);
  }
}

// ─── Results Count ────────────────────────────────────────────

class _ResultsCount extends StatelessWidget {
  final int count;
  final int total;
  const _ResultsCount({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final isFiltered = count != total;
    return Text(
      isFiltered ? 'Showing $count of $total tickets' : '$count ticket${count != 1 ? 's' : ''}',
      style: AppTypography.caption.copyWith(color: context.colors.hint),
    );
  }
}
