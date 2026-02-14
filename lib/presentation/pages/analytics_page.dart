/// Sellio Metrics — Analytics Page
///
/// Displays spotlights at the top, slow PRs section.
/// Uses domain entities, localized strings, and theme extension.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
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
        final spotlight = provider.spotlightMetrics;
        final bottlenecks = provider.bottlenecks;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spotlight Section — at the top
              _buildSectionHeader(
                context,
                l10n.sectionSpotlight,
                emoji: '✨',
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSpotlightGrid(context, spotlight),

              const SizedBox(height: AppSpacing.xxl),

              // Filter bar
              const DateRangeFilter(),

              const SizedBox(height: AppSpacing.xxl),

              // Slow PRs Section (formerly Bottlenecks)
              if (bottlenecks.isNotEmpty) ...[
                _buildSlowPrsSection(context, bottlenecks, l10n),
              ],
            ],
          ),
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

  Widget _buildSlowPrsSection(
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
            emoji: '🐢',
            count: bottlenecks.length,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...bottlenecks.map((b) => BottleneckItem(bottleneck: b)),
      ],
    );
  }
}
