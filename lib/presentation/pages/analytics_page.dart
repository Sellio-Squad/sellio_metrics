/// Sellio Metrics — Analytics Page
///
/// Displays KPI cards, spotlights, bottleneck analysis, and collaboration.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/kpi_card.dart';
import '../widgets/spotlight_card.dart';
import '../widgets/bottleneck_item.dart';
import '../widgets/filter_bar.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final kpis = provider.kpis;
        final spotlight = provider.spotlightMetrics;
        final bottlenecks = provider.bottlenecks;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter bar
              const FilterBar(),
              const SizedBox(height: AppSpacing.xl),

              // KPI Cards Grid
              LayoutBuilder(
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
                        label: AppStrings.kpiTotalPrs,
                        value: '${kpis.totalPrs}',
                        icon: Icons.call_merge,
                        accentColor: SellioColors.kpiFuchsia,
                      ),
                      KpiCard(
                        label: AppStrings.kpiMergedPrs,
                        value: '${kpis.mergedPrs}',
                        icon: Icons.merge_type,
                        accentColor: SellioColors.kpiPurple,
                        subtitle:
                            '${kpis.mergeRate.toStringAsFixed(0)}% merge rate',
                      ),
                      KpiCard(
                        label: AppStrings.kpiClosedPrs,
                        value: '${kpis.closedPrs}',
                        icon: Icons.close,
                        accentColor: SellioColors.danger,
                      ),
                      KpiCard(
                        label: AppStrings.kpiAvgPrSize,
                        value: kpis.avgPrSize,
                        icon: Icons.code,
                        accentColor: SellioColors.kpiBlue,
                      ),
                      KpiCard(
                        label: AppStrings.kpiTotalComments,
                        value: '${kpis.totalComments}',
                        icon: Icons.comment_outlined,
                        accentColor: SellioColors.kpiCyan,
                      ),
                      KpiCard(
                        label: AppStrings.kpiAvgComments,
                        value: kpis.avgComments,
                        icon: Icons.chat_bubble_outline,
                        accentColor: SellioColors.kpiPink,
                      ),
                      KpiCard(
                        label: AppStrings.kpiAvgApproval,
                        value: kpis.avgApprovalTime,
                        icon: Icons.timer_outlined,
                        accentColor: SellioColors.success,
                      ),
                      KpiCard(
                        label: AppStrings.kpiAvgLifespan,
                        value: kpis.avgLifespan,
                        icon: Icons.hourglass_bottom,
                        accentColor: SellioColors.warning,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Spotlight Section
              Text(
                AppStrings.sectionSpotlight,
                style: AppTypography.title.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
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
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Bottleneck Section
              if (bottlenecks.isNotEmpty) ...[
                Row(
                  children: [
                    const Text('🚨', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.sectionBottlenecks,
                      style: AppTypography.title.copyWith(
                        color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: SellioColors.danger.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        '${bottlenecks.length}',
                        style: AppTypography.caption.copyWith(
                          color: SellioColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ...bottlenecks.map((b) => BottleneckItem(bottleneck: b)),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Collaboration Section
              if (provider.collaborationPairs.isNotEmpty) ...[
                Text(
                  AppStrings.sectionCollaboration,
                  style: AppTypography.title.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF1a1a2e),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2E2E3E)
                          : const Color(0xFFE5E7EB),
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
                            Icon(
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
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1a1a2e),
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
            ],
          ),
        );
      },
    );
  }
}
