library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';
import 'empty_state.dart';
import 'pr_list_tile.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/section_header.dart';
import 'bottleneck_item.dart';
import '../../providers/app_settings_provider.dart';

class OpenPrsPage extends StatefulWidget {
  const OpenPrsPage({super.key});

  @override
  State<OpenPrsPage> createState() => _OpenPrsPageState();
}

class _OpenPrsPageState extends State<OpenPrsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();
      dashboard.ensureDataLoaded(settings.selectedRepos);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final prs = provider.openPrs;
        final scheme = context.colors;
        final kpis = provider.kpis;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Analytics Section
                          SectionHeader(
                            icon: LucideIcons.barChart3,
                            title: l10n.navAnalytics, // Or maybe a more specific title
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          // Responsive KPIs
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 800;
                              final isMedium = constraints.maxWidth > 500 && constraints.maxWidth <= 800;

                              final k1 = KpiCard(
                                label: l10n.kpiTotalPrs,
                                value: kpis.totalPrs.toString(),
                                icon: Icons.numbers,
                                accentColor: scheme.primary,
                              );
                              final k2 = KpiCard(
                                label: l10n.kpiAvgApproval,
                                value: kpis.avgApprovalTime,
                                icon: Icons.access_time,
                                accentColor: scheme.secondary,
                              );
                              final k3 = KpiCard(
                                label: l10n.kpiAvgLifespan,
                                value: kpis.avgLifespan,
                                icon: Icons.timeline,
                                accentColor: scheme.green,
                              );
                              final k4 = KpiCard(
                                label: l10n.kpiAvgPrSize,
                                value: kpis.avgPrSize,
                                icon: Icons.code,
                                accentColor: SellioColors.purple,
                              );

                              if (isWide) {
                                return Row(
                                  children: [
                                    Expanded(child: k1),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(child: k2),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(child: k3),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(child: k4),
                                  ],
                                );
                              } else if (isMedium) {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: k1),
                                        const SizedBox(width: AppSpacing.lg),
                                        Expanded(child: k2),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Row(
                                      children: [
                                        Expanded(child: k3),
                                        const SizedBox(width: AppSpacing.lg),
                                        Expanded(child: k4),
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  k1,
                                  const SizedBox(height: AppSpacing.lg),
                                  k2,
                                  const SizedBox(height: AppSpacing.lg),
                                  k3,
                                  const SizedBox(height: AppSpacing.lg),
                                  k4,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          const SizedBox(height: AppSpacing.xl),

                          // Search bar directly above Open PRs
                          SInput(
                            hint: l10n.searchPlaceholder,
                            onChanged: (value) => provider.setSearchTerm(value),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Count badge for Open PRs
                          Row(
                            children: [
                              Text(
                                l10n.sectionOpenPrs,
                                style: AppTypography.title.copyWith(color: scheme.title),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SBadge(
                                label: '${prs.length}',
                                variant: SBadgeVariant.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    prs.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(scheme: scheme, l10n: l10n),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => PrListTile(pr: prs[index]),
                              childCount: prs.length,
                            ),
                          ),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

