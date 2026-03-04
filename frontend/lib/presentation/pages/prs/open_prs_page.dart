library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';
import 'pr_list_tile.dart';
import '../../../domain/entities/pr_entity.dart';
import '../../widgets/kpi_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../widgets/section_header.dart';
import 'bottleneck_item.dart';
import '../../providers/app_settings_provider.dart';

class OpenPrsPage extends StatefulWidget {
  const OpenPrsPage({super.key});

  @override
  State<OpenPrsPage> createState() => _OpenPrsPageState();
}

class _OpenPrsPageState extends State<OpenPrsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();
      dashboard.ensureDataLoaded(settings.selectedRepos);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final prs = provider.openPrs;
        final scheme = context.colors;
        final kpis = provider.kpis;
        final mergedPrs = provider.weekFilteredPrs
            .where((pr) => pr.mergedAt != null)
            .toList()
          ..sort((a, b) => a.mergedAt!.compareTo(b.mergedAt!));

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar only — no status filter
              SInput(
                hint: l10n.searchPlaceholder,
                onChanged: (value) => provider.setSearchTerm(value),
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Analytics Section
                          SectionHeader(
                            icon: LucideIcons.barChart3,
                            title: l10n.navAnalytics, // Or maybe a more specific title
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          // KPI row
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 900;
                              final children = [
                                Expanded(
                                  child: KpiCard(
                                    label: l10n.kpiTotalPrs,
                                    value: kpis.totalPrs.toString(),
                                    icon: Icons.numbers,
                                    accentColor: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: KpiCard(
                                    label: l10n.kpiAvgApproval,
                                    value: kpis.avgApprovalTime,
                                    icon: Icons.access_time,
                                    accentColor: scheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: KpiCard(
                                    label: l10n.kpiAvgLifespan,
                                    value: kpis.avgLifespan,
                                    icon: Icons.timeline,
                                    accentColor: scheme.green,
                                  ),
                                ),
                              ];

                              if (isWide) {
                                return Row(children: children);
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  children[0],
                                  const SizedBox(height: AppSpacing.lg),
                                  children[2],
                                  const SizedBox(height: AppSpacing.lg),
                                  children[4],
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          // Merge time over time chart
                          SectionHeader(
                            icon: LucideIcons.activity,
                            title: l10n.sectionPrActivity,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _MergeLifespanChart(mergedPrs: mergedPrs),
                          const SizedBox(height: AppSpacing.xxl),

                          // Count badge for Open PRs
                          Row(
                            children: [
                              Text(
                                l10n.sectionOpenPrs,
                                style: AppTypography.title.copyWith(color: scheme.title),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SBadge(
                                label: '${prs.length}',
                                variant: SBadgeVariant.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    prs.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(scheme: scheme, l10n: l10n),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => PrListTile(pr: prs[index]),
                              childCount: prs.length,
                            ),
                          ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.xxl),
                          // Slow PRs section
                          SectionHeader(
                            icon: LucideIcons.alertTriangle,
                            title: l10n.sectionBottlenecks,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (provider.bottlenecks.isEmpty)
                            Text(
                              l10n.emptyData,
                              style: AppTypography.body.copyWith(color: scheme.hint),
                            )
                          else
                            ...provider.bottlenecks.map(
                              (b) => BottleneckItem(bottleneck: b),
                            ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
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

class _EmptyState extends StatelessWidget {
  final SellioColorScheme scheme;
  final AppLocalizations l10n;

  const _EmptyState({required this.scheme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: scheme.hint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.searchNoResults,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ],
      ),
    );
  }
}

/// Line chart: each merged PR plotted by merge date (x) vs lifespan in hours (y).
class _MergeLifespanChart extends StatelessWidget {
  final List<PrEntity> mergedPrs;

  const _MergeLifespanChart({required this.mergedPrs});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (mergedPrs.isEmpty) {
      return SCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            AppLocalizations.of(context).emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < mergedPrs.length; i++) {
      final pr = mergedPrs[i];
      final minutes =
      pr.mergedAt!.difference(pr.openedAt).inMinutes.toDouble();
      final hours = minutes / 60;
      spots.add(FlSpot(i.toDouble(), hours));
    }

    final dateFormat = DateFormat('MM/dd');

    return SCard(
      child: SizedBox(
        height: 280,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (mergedPrs.length - 1).toDouble(),
              gridData: FlGridData(show: true),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: scheme.stroke),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toStringAsFixed(1)}h',
                      style: AppTypography.caption.copyWith(
                        color: scheme.hint,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: (mergedPrs.length / 6).clamp(1, 6).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= mergedPrs.length) {
                        return const SizedBox.shrink();
                      }
                      final date = mergedPrs[index].mergedAt!;
                      return Text(
                        dateFormat.format(date),
                        style: AppTypography.caption.copyWith(
                          color: scheme.hint,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  color: scheme.primary,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: scheme.primary.withValues(alpha: 0.12),
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
