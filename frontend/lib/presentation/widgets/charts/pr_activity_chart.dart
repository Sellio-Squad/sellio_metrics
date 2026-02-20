/// Sellio Metrics — PR Activity Line Chart Widget
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';

class PrActivityChart extends StatelessWidget {
  final DashboardProvider provider;

  const PrActivityChart({super.key, required this.provider});

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

class _WeeklyActivity {
  int opened = 0;
  int merged = 0;
}
