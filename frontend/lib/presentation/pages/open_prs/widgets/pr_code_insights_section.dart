/// PR Code Insights Section
///
/// Displays file-type breakdown and actionable insights from PR analysis.

import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/domain/entities/pr_code_insight.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/services/pr_analysis_service.dart';

class PrCodeInsightsSection extends StatelessWidget {
  final PrEntity pr;

  const PrCodeInsightsSection({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final insights = PrAnalysisService.generateInsights(pr);

    return _SectionCard(
      title: 'Code Insights',
      icon: Icons.code_outlined,
      scheme: scheme,
      child: insights.isEmpty
          ? Text(
              'No insights available for this PR.',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insights
                  .map((insight) => _InsightRow(insight: insight))
                  .toList(),
            ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final PrCodeInsight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (icon, color) = switch (insight.severity) {
      PrInsightSeverity.info => (Icons.info_outline, scheme.primary),
      PrInsightSeverity.warning => (Icons.warning_amber_rounded, SellioColors.amber),
      PrInsightSeverity.tip => (Icons.lightbulb_outline, scheme.green),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.category,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  insight.message,
                  style: AppTypography.caption.copyWith(
                    color: scheme.body,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final dynamic scheme;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.scheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.hint),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
