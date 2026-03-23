import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';

class AttendanceAnalyticsView extends StatelessWidget {
  const AttendanceAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final analytics = context.watch<MeetingsProvider>().analytics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meetingAnalytics,
          style: AppTypography.title.copyWith(
            fontSize: 20,
            color: scheme.title,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Key Metrics
        Row(
          children: [
            _MetricCard(
              label: l10n.totalMeetings,
              value: analytics.totalMeetings.toString(),
              icon: LucideIcons.video,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.lg),
            _MetricCard(
              label: l10n.totalAttendees,
              value: analytics.totalAttendees.toString(),
              icon: LucideIcons.users,
              color: scheme.green,
            ),
            const SizedBox(width: AppSpacing.lg),
            _MetricCard(
              label: l10n.avgDuration,
              value: '${analytics.averageDurationMinutes}m',
              icon: LucideIcons.clock,
              color: SellioColors.amber,
            ),
            const SizedBox(width: AppSpacing.lg),
            _MetricCard(
              label: l10n.avgScore,
              value: '${analytics.averageScore}%',
              icon: LucideIcons.checkCircle,
              color: SellioColors.blue,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // Layout: Trend Chart + Most Active list
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildTrendChart(context, analytics)),
            const SizedBox(width: AppSpacing.xl),
            Expanded(flex: 1, child: _buildMostActiveCard(context, analytics)),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendChart(BuildContext context, dynamic analytics) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final trends = analytics.attendanceTrends as List;

    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), trends[i].attendeeCount.toDouble()));
    }

    // Determine max Y for scaling
    double maxY = 0;
    for (final spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = maxY + (maxY * 0.2); // Add 20% headroom
    if (maxY == 0) maxY = 10;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart2, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.attendanceTrends,
                style: AppTypography.title.copyWith(
                  fontSize: 16,
                  color: scheme.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 10 ? (maxY / 4) : 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.stroke,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < trends.length) {
                          final dateRaw = trends[i].date.toString();
                          // Take MM-DD part for brevity
                          final parts = dateRaw.split('-');
                          if (parts.length >= 3) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${parts[1]}/${parts[2]}',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTypography.caption.copyWith(
                            color: scheme.hint,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (trends.length - 1).toDouble() < 0
                    ? 0
                    : (trends.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: scheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostActiveCard(BuildContext context, dynamic analytics) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final topList = analytics.mostActiveParticipants as List;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.award, size: 20, color: SellioColors.amber),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.mostActiveParticipants,
                style: AppTypography.title.copyWith(
                  fontSize: 16,
                  color: scheme.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: topList.isEmpty
                ? Center(
                    child: Text(
                      'No data yet.',
                      style: AppTypography.caption.copyWith(color: scheme.hint),
                    ),
                  )
                : ListView.separated(
                    itemCount: topList.length,
                    separatorBuilder: (_, __) => Divider(color: scheme.stroke),
                    itemBuilder: (context, index) {
                      final p = topList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            SAvatar(
                              name: p.displayName,
                              size: SAvatarSize.small,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.displayName,
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: scheme.title,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${p.meetingsAttended} meets, ${p.totalMinutes}m',
                                    style: AppTypography.caption.copyWith(
                                      color: scheme.hint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.green.withValues(alpha: 0.1),
                                borderRadius: AppRadius.smAll,
                              ),
                              child: Text(
                                '${p.averageScore}%',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: AppTypography.title.copyWith(
                fontSize: 28,
                color: scheme.title,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
