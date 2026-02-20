/// Sellio Metrics — PR Type Pie Chart Widget
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';

class PrTypePieChart extends StatelessWidget {
  final DashboardProvider provider;

  const PrTypePieChart({super.key, required this.provider});

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
