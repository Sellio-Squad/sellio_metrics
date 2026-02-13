/// Sellio Metrics — Analytics Page
///
/// Displays KPI cards, spotlights, bottleneck analysis, and collaboration.
/// Uses domain entities, localized strings, and theme extension.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/kpi_card.dart';
import '../widgets/spotlight_card.dart';
import '../widgets/bottleneck_item.dart';
import '../widgets/filters/date_range_filter.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context);
        final kpis = provider.kpis;
        final spotlight = provider.spotlightMetrics;
        final bottlenecks = provider.bottlenecks;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter bar
              const DateRangeFilter(),
              const SizedBox(height: AppSpacing.xl),

              // KPI Cards
              HuxTooltip(
                message: l10n.tooltipKpi,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.kpiMergeRate,
                    style: AppTypography.title.copyWith(
                      color: context.isDark
                          ? Colors.white
                          : SellioColors.gray700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildKpiGrid(context, kpis, l10n),

              const SizedBox(height: AppSpacing.xxl),

              // Spotlight Section
              _buildSectionHeader(
                context,
                l10n.sectionSpotlight,
                emoji: '✨',
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSpotlightGrid(context, spotlight),

              const SizedBox(height: AppSpacing.xxl),

              // Bottleneck Section
              if (bottlenecks.isNotEmpty) ...[
                _buildBottleneckSection(context, bottlenecks, l10n),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Collaboration Section
              if (provider.collaborationPairs.isNotEmpty) ...[
                _buildCollaborationSection(context, provider, l10n),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiGrid(BuildContext context, kpis, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 500
                    ? 2
                    : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            KpiCard(
              label: l10n.kpiTotalPrs,
              value: '${kpis.totalPrs}',
              icon: Icons.call_merge,
              accentColor: SellioColors.kpiFuchsia,
            ),
            KpiCard(
              label: l10n.kpiMergedPrs,
              value: '${kpis.mergedPrs}',
              icon: Icons.merge_type,
              accentColor: SellioColors.kpiPurple,
              subtitle:
                  '${kpis.mergeRate.toStringAsFixed(0)}% merge rate',
            ),
            KpiCard(
              label: l10n.kpiClosedPrs,
              value: '${kpis.closedPrs}',
              icon: Icons.close,
              accentColor: SellioColors.danger,
            ),
            KpiCard(
              label: l10n.kpiAvgPrSize,
              value: kpis.avgPrSize,
              icon: Icons.code,
              accentColor: SellioColors.kpiBlue,
            ),
            KpiCard(
              label: l10n.kpiTotalComments,
              value: '${kpis.totalComments}',
              icon: Icons.comment_outlined,
              accentColor: SellioColors.kpiCyan,
            ),
            KpiCard(
              label: l10n.kpiAvgComments,
              value: kpis.avgComments,
              icon: Icons.chat_bubble_outline,
              accentColor: SellioColors.kpiPink,
            ),
            KpiCard(
              label: l10n.kpiAvgApproval,
              value: kpis.avgApprovalTime,
              icon: Icons.timer_outlined,
              accentColor: SellioColors.success,
            ),
            KpiCard(
              label: l10n.kpiAvgLifespan,
              value: kpis.avgLifespan,
              icon: Icons.hourglass_bottom,
              accentColor: SellioColors.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpotlightGrid(BuildContext context, spotlight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          children: [
            SpotlightCard(
              title: 'Hot Streak',
              emoji: '🔥',
              metric: spotlight.hotStreak,
              accentColor: SellioColors.danger,
            ),
            SpotlightCard(
              title: 'Fastest Reviewer',
              emoji: '⚡',
              metric: spotlight.fastestReviewer,
              accentColor: SellioColors.warning,
            ),
            SpotlightCard(
              title: 'Top Commenter',
              emoji: '💬',
              metric: spotlight.topCommenter,
              accentColor: SellioColors.info,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? emoji,
    int? count,
  }) {
    return Row(
      children: [
        if (emoji != null) ...[
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTypography.title.copyWith(
            color: context.isDark ? Colors.white : SellioColors.gray700,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: SellioColors.danger.withAlpha(25),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: SellioColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottleneckSection(
    BuildContext context,
    List bottlenecks,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HuxTooltip(
          message: l10n.tooltipBottleneck,
          child: _buildSectionHeader(
            context,
            l10n.sectionBottlenecks,
            emoji: '🚨',
            count: bottlenecks.length,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...bottlenecks.map((b) => BottleneckItem(bottleneck: b)),
      ],
    );
  }

  Widget _buildCollaborationSection(
    BuildContext context,
    DashboardProvider provider,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          l10n.sectionCollaboration,
          emoji: '🤝',
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.isDark
                ? SellioColors.darkSurface
                : SellioColors.lightSurface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: context.isDark
                  ? Colors.white10
                  : SellioColors.gray300,
            ),
          ),
          child: Column(
            children: provider.collaborationPairs.map((pair) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 18,
                      color: SellioColors.primaryIndigo,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        pair.reviewer,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.isDark
                              ? Colors.white
                              : SellioColors.gray700,
                        ),
                      ),
                    ),
                    Text(
                      '${pair.totalReviews} reviews',
                      style: AppTypography.caption.copyWith(
                        color: SellioColors.primaryIndigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
