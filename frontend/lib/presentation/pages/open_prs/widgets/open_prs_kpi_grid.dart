library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../domain/entities/kpi_entity.dart';
import '../../../widgets/kpi_card.dart';
import '../../../widgets/section_header.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../../../design_system/design_system.dart';

class OpenPrsKpiGrid extends StatelessWidget {
  final KpiEntity kpis;

  const OpenPrsKpiGrid({super.key, required this.kpis});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          icon: LucideIcons.barChart3,
          title: l10n.navAnalytics,
        ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final cards = [
              KpiCard(
                label: l10n.kpiTotalPrs,
                value: kpis.totalPrs.toString(),
                icon: Icons.numbers,
                accentColor: scheme.primary,
              ),
              KpiCard(
                label: l10n.kpiAvgApproval,
                value: kpis.avgApprovalTime,
                icon: Icons.access_time,
                accentColor: scheme.secondary,
              ),
              KpiCard(
                label: l10n.kpiAvgPrSize,
                icon: Icons.code,
                accentColor: SellioColors.purple,
                // No plain value — use richValue instead
                richValue: TextSpan(
                  children: [
                    TextSpan(
                      text: '+${kpis.avgAdditions}',
                      style: AppTypography.kpiValue.copyWith(
                        color: scheme.green,
                      ),
                    ),
                    TextSpan(
                      text: ' / ',
                      style: AppTypography.kpiValue.copyWith(
                        color: scheme.hint,
                      ),
                    ),
                    TextSpan(
                      text: '-${kpis.avgDeletions}',
                      style: AppTypography.kpiValue.copyWith(
                        color: scheme.red,
                      ),
                    ),
                  ],
                ),
              ),
            ];

            if (width >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.lg),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }

            if (width >= 500) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: cards[2]),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  cards[i],
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}