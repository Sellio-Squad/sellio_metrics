library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';
import 'section_header.dart';
import 'bottleneck_item.dart';
import 'spotlight_card.dart';
import 'date_filter/date_range_filter.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final scheme = context.colors;

        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DateRangeFilter(),
                const SizedBox(height: AppSpacing.xxl),

                SectionHeader(
                  icon: LucideIcons.star,
                  title: l10n.sectionSpotlight,
                ),
                const SizedBox(height: AppSpacing.lg),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > LayoutConstants.mobileBreakpoint ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2,
                      children: [
                        SpotlightCard(
                          icon: LucideIcons.flame,
                          title: l10n.spotlightHotStreak,
                          metric: provider.spotlightMetrics.hotStreak,
                          accentColor: scheme.secondary,
                        ),
                        SpotlightCard(
                          icon: LucideIcons.zap,
                          title: l10n.spotlightFastestReviewer,
                          metric: provider.spotlightMetrics.fastestReviewer,
                          accentColor: scheme.green,
                        ),
                        SpotlightCard(
                          icon: LucideIcons.messageCircle,
                          title: l10n.spotlightTopCommenter,
                          metric: provider.spotlightMetrics.topCommenter,
                          accentColor: scheme.primary,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Slow PRs section
                SectionHeader(
                  icon: LucideIcons.alertTriangle,
                  title: l10n.sectionBottlenecks,
                ),

                const SizedBox(height: AppSpacing.lg),
                if (provider.bottlenecks.isEmpty)
                  Text(
                    l10n.emptyData,
                    style: AppTypography.body.copyWith(color: scheme.hint),
                  )
                else
                  ...provider.bottlenecks.map(
                    (b) => BottleneckItem(bottleneck: b),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
