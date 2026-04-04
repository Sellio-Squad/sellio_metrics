import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/providers/issues_provider.dart';

class IssuesSummarySection extends StatelessWidget {
  final IssueSummaryMetrics metrics;

  const IssuesSummarySection({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cards = [
          _KpiCard(
            label: 'Total Open Issues',
            value: '${metrics.total}',
            icon: LucideIcons.alertCircle,
            color: context.colors.primary,
            bgColor: context.colors.primaryVariant,
          ),
          _KpiCard(
            label: 'Without Deadlines',
            value: '${metrics.noDeadline}',
            icon: LucideIcons.calendarX,
            color: const Color(0xFFF5A623),
            bgColor: const Color(0xFFF5A623).withValues(alpha: 0.12),
          ),
          _KpiCard(
            label: 'Overdue',
            value: '${metrics.overdue}',
            icon: LucideIcons.alarmClock,
            color: context.colors.red,
            bgColor: context.colors.errorVariant,
          ),
          _KpiCard(
            label: 'Unassigned',
            value: '${metrics.unassigned}',
            icon: LucideIcons.userX,
            color: const Color(0xFF3B82F6),
            bgColor: const Color(0xFF3B82F6).withValues(alpha: 0.10),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [Expanded(child: cards[0]), const SizedBox(width: AppSpacing.md), Expanded(child: cards[1])]),
              const SizedBox(height: AppSpacing.md),
              Row(children: [Expanded(child: cards[2]), const SizedBox(width: AppSpacing.md), Expanded(child: cards[3])]),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.kpiValue.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: scheme.hint),
          ),
        ],
      ),
    );
  }
}
