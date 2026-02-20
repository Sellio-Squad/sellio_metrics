/// Sellio Metrics — Code Volume Chart Widget
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';

class CodeVolumeChart extends StatelessWidget {
  final DashboardProvider provider;

  const CodeVolumeChart({super.key, required this.provider});

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

class _CodeVolume {
  int additions = 0;
  int deletions = 0;
}
