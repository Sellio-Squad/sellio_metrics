library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';
import 'pr_list_tile.dart';
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

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar only — no status filter
              SInput(
                hint: l10n.searchPlaceholder,
                onChanged: (value) => provider.setSearchTerm(value),
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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

                          // Count badge
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
                            child: _EmptyState(scheme: scheme, l10n: l10n),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => PrListTile(pr: prs[index]),
                              childCount: prs.length,
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

class _EmptyState extends StatelessWidget {
  final SellioColorScheme scheme;
  final AppLocalizations l10n;

  const _EmptyState({required this.scheme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: scheme.hint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.searchNoResults,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ],
      ),
    );
  }
}
