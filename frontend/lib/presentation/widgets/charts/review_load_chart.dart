/// Sellio Metrics — Review Load Bar Chart Widget
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';

class ReviewLoadChart extends StatelessWidget {
  final DashboardProvider provider;

  const ReviewLoadChart({super.key, required this.provider});

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
