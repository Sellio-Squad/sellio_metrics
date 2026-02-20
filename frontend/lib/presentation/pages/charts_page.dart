/// Sellio Metrics — Charts Page
///
/// Dedicated analytics visualization page with PR activity,
/// type distribution, review time, and code volume charts.
/// Delegates each chart to its own widget file.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/charts/chart_card.dart';
import '../widgets/charts/pr_type_pie_chart.dart';
import '../widgets/charts/pr_activity_chart.dart';
import '../widgets/charts/review_load_chart.dart';
import '../widgets/charts/code_volume_chart.dart';

class ChartsPage extends StatelessWidget {
  const ChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final l10n = AppLocalizations.of(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChartCard(
                title: l10n.sectionPrTypes,
                child: PrTypePieChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              ChartCard(
                title: l10n.sectionPrActivity,
                child: PrActivityChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              ChartCard(
                title: l10n.sectionReviewTime,
                child: ReviewLoadChart(provider: provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              ChartCard(
                title: l10n.sectionCodeVolume,
                child: CodeVolumeChart(provider: provider),
              ),
            ],
          ),
        );
      },
    );
  }
}
