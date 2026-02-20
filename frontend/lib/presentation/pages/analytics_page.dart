library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/bottleneck_item.dart';
import '../widgets/filters/date_range_filter.dart';
import '../widgets/spotlight_card.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final scheme = context.colors;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date filter — no developer dropdown
              const DateRangeFilter(),
              const SizedBox(height: AppSpacing.xxl),

              // Spotlight section
              _SectionHeader(
                emoji: '🌟',
                title: l10n.sectionSpotlight,
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                  constraints.maxWidth > 800 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    children: [
                      SpotlightCard(
                        emoji: '🔥',
                        title: l10n.spotlightHotStreak,
                        metric: provider.spotlightMetrics.hotStreak,
                        accentColor: scheme.secondary,
                      ),
                      SpotlightCard(
                        emoji: '⚡',
                        title: l10n.spotlightFastestReviewer,
                        metric: provider.spotlightMetrics.fastestReviewer,
                        accentColor: scheme.green,
                      ),
                      SpotlightCard(
                        emoji: '💬',
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
              _SectionHeader(
                emoji: '🐢',
                title: l10n.sectionBottlenecks,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (provider.bottlenecks.isEmpty)
                Text(
                  l10n.emptyData,
                  style: AppTypography.body.copyWith(color: scheme.hint),
                )
              else
                ...provider.bottlenecks
                    .map((b) => BottleneckItem(bottleneck: b)),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable section header with emoji + title.
class _SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;

  const _SectionHeader({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.title.copyWith(color: scheme.title),
        ),
      ],
    );
  }
}
