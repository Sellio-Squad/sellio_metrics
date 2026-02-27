library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/pr_entity.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/section_header.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kpis = provider.kpis;
        final scheme = context.colors;

        final mergedPrs = provider.weekFilteredPrs
            .where((pr) => pr.mergedAt != null)
            .toList()
          ..sort((a, b) => a.mergedAt!.compareTo(b.mergedAt!));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: LucideIcons.barChart3,
                title: l10n.navAnalytics,
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
            ],
          ),
        );
      },
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