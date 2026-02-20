/// Sellio Metrics — Charts Page
///
/// Dedicated analytics visualization page with PR activity,
/// type distribution, review time, and code volume charts.
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../core/utils/date_utils.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';

class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChartCard(
                title: l10n.sectionPrTypes,
                child: _PrTypePieChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ChartCard(
                title: l10n.sectionPrActivity,
                child: _PrActivityChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ChartCard(
                title: l10n.sectionReviewTime,
                child: _ReviewLoadChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ChartCard(
                title: l10n.sectionCodeVolume,
                child: _CodeVolumeChart(provider: provider),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Chart Card Container ─────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

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
          Text(
            title,
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}

// ─── PR Type Pie Chart ────────────────────────────────────

class _PrTypePieChart extends StatelessWidget {
  final DashboardProvider provider;

  const _PrTypePieChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final types = provider.prTypeDistribution;

    if (types.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            AppLocalizations.of(context).emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ),
      );
    }

    final entries = types.entries.toList();
    final total = entries.fold(0, (s, e) => s + e.value);

    return SizedBox(
      height: 300,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: entries.asMap().entries.map((mapEntry) {
                  final i = mapEntry.key;
                  final entry = mapEntry.value;
                  final color = SellioColors
                      .chartPalette[i % SellioColors.chartPalette.length];
                  final percentage = (entry.value / total * 100);
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: '${percentage.toStringAsFixed(0)}%',
                    color: color,
                    radius: 60,
                    titleStyle: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((mapEntry) {
                final i = mapEntry.key;
                final entry = mapEntry.value;
                final color = SellioColors
                    .chartPalette[i % SellioColors.chartPalette.length];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${entry.key} (${entry.value})',
                        style: AppTypography.caption
                            .copyWith(color: scheme.body),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PR Activity Line Chart ───────────────────────────────

class _PrActivityChart extends StatelessWidget {
  final DashboardProvider provider;

  const _PrActivityChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final weeklyData = <String, _WeeklyActivity>{};

    for (final pr in provider.weekFilteredPrs) {
      final week = formatShortDate(pr.openedAt);
      weeklyData.putIfAbsent(week, () => _WeeklyActivity());
      weeklyData[week]!.opened++;
      if (pr.isMerged) weeklyData[week]!.merged++;
    }

    if (weeklyData.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            AppLocalizations.of(context).emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ),
      );
    }

    final weeks = weeklyData.keys.toList();
    final openedSpots = weeks.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), weeklyData[e.value]!.opened.toDouble());
    }).toList();
    final mergedSpots = weeks.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), weeklyData[e.value]!.merged.toDouble());
    }).toList();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.stroke,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(weeks[idx], style: AppTypography.overline);
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _lineBarData(openedSpots, scheme.primary),
            _lineBarData(mergedSpots, scheme.green),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(25),
      ),
    );
  }
}

// ─── Review Load Bar Chart ────────────────────────────────

class _ReviewLoadChart extends StatelessWidget {
  final DashboardProvider provider;

  const _ReviewLoadChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final reviewLoad = provider.reviewLoad;

    if (reviewLoad.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            AppLocalizations.of(context).emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ),
      );
    }

    final maxY = reviewLoad
        .map((e) => e.reviewsGiven.toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.stroke,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= reviewLoad.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    reviewLoad[idx].developer.length > 8
                        ? '${reviewLoad[idx].developer.substring(0, 8)}…'
                        : reviewLoad[idx].developer,
                    style: AppTypography.overline,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: reviewLoad.asMap().entries.map((entry) {
            final color = SellioColors
                .chartPalette[entry.key % SellioColors.chartPalette.length];
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.reviewsGiven.toDouble(),
                  color: color,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Code Volume Chart ────────────────────────────────────

class _CodeVolumeChart extends StatelessWidget {
  final DashboardProvider provider;

  const _CodeVolumeChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final prs = provider.weekFilteredPrs;

    if (prs.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            AppLocalizations.of(context).emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ),
      );
    }

    // Group by week
    final weeklyVolume = <String, _CodeVolume>{};
    for (final pr in prs) {
      final week = formatShortDate(pr.openedAt);
      weeklyVolume.putIfAbsent(week, () => _CodeVolume());
      weeklyVolume[week]!.additions += pr.diffStats.additions;
      weeklyVolume[week]!.deletions += pr.diffStats.deletions;
    }

    final weeks = weeklyVolume.keys.toList();
    final maxVal = weeklyVolume.values
        .map((v) => (v.additions + v.deletions).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.stroke,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= weeks.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(weeks[idx], style: AppTypography.overline);
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: weeks.asMap().entries.map((entry) {
            final vol = weeklyVolume[entry.value]!;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (vol.additions + vol.deletions).toDouble(),
                  rodStackItems: [
                    BarChartRodStackItem(
                        0, vol.additions.toDouble(), scheme.green),
                    BarChartRodStackItem(
                        vol.additions.toDouble(),
                        (vol.additions + vol.deletions).toDouble(),
                        scheme.red),
                  ],
                  width: 20,
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _WeeklyActivity {
  int opened = 0;
  int merged = 0;
}

class _CodeVolume {
  int additions = 0;
  int deletions = 0;
}
