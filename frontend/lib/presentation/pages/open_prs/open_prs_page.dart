
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/domain/services/filter_service.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/analytics_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/filter_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/widgets/common/error_screen.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/open_prs_header.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/open_prs_kpi_grid.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/open_prs_list.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/open_prs_bottleneck_section.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_size_overview_section.dart';

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
      context.read<PrDataProvider>().loadOpenPrs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PrDataProvider, FilterProvider, AnalyticsProvider>(
      builder: (context, prData, filter, analytics, _) {
        // Loading state
        if (prData.openPrsStatus == DataLoadingStatus.loading &&
            prData.openPrs.isEmpty) {
          return const LoadingScreen();
        }

        // Error state
        if (prData.openPrsStatus == DataLoadingStatus.error &&
            prData.openPrs.isEmpty) {
          return ErrorScreen(onRetry: () => prData.loadOpenPrs());
        }

        // Filter pipeline
        final filterService = getIt<FilterService>();
        final weekFiltered = filterService.filterByWeek(
          filterService.filterByDateRange(
            prData.openPrs,
            filter.startDate,
            filter.endDate,
          ),
          filter.weekFilter,
        );

        // Search filter
        final filteredPrs = prData.openPrs.where((pr) {
          if (filter.searchTerm.isEmpty) return true;
          final term = filter.searchTerm.toLowerCase();
          return pr.title.toLowerCase().contains(term) ||
              pr.creator.login.toLowerCase().contains(term);
        }).toList();

        // Analytics
        final kpis = analytics.calculateKpis(
          weekFiltered,
          developerFilter: filter.developerFilter,
        );
        final bottlenecks = analytics.identifyBottlenecks(
          weekFiltered,
          thresholdHours: filter.bottleneckThreshold,
        );

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // 1. KPI Cards
                    SliverToBoxAdapter(
                      child: OpenPrsKpiGrid(kpis: kpis),
                    ),

                    // 2. Bottlenecks — NOW ABOVE PRs
                    SliverToBoxAdapter(
                      child: OpenPrsBottleneckSection(
                        bottlenecks: bottlenecks,
                      ),
                    ),

                    // 3. Large PRs — Size hints
                    SliverToBoxAdapter(
                      child: PrSizeOverviewSection(prs: filteredPrs),
                    ),

                    // 3. Search + Count header
                    SliverToBoxAdapter(
                      child: OpenPrsHeader(
                        prCount: filteredPrs.length,
                        onSearchChanged: (v) => filter.setSearchTerm(v),
                      ),
                    ),

                    // 4. PR List
                    OpenPrsList(prs: filteredPrs),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
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
