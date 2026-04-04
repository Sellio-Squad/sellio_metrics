import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/ticket_entity.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/providers/tickets_provider.dart';

class TicketsInsightsSection extends StatelessWidget {
  final List<ScrumInsight> insights;

  const TicketsInsightsSection({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: [
                Icon(LucideIcons.brain, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Scrum Insights', style: AppTypography.subtitle.copyWith(color: scheme.title)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: scheme.stroke, height: 1),
          ...insights.asMap().entries.map((entry) {
            final i = entry.key;
            final insight = entry.value;
            final isLast = i == insights.length - 1;
            final borderColor = switch (insight.severity) {
              TicketHealthStatus.overdue    => scheme.red,
              TicketHealthStatus.noDeadline => const Color(0xFFF5A623),
              TicketHealthStatus.healthy    => scheme.green,
            };
            return Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: borderColor, width: 3)),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Text(insight.message,
                    style: AppTypography.body.copyWith(color: scheme.body)),
                ),
                if (!isLast)
                  Divider(color: scheme.stroke, height: 1,
                    indent: AppSpacing.lg, endIndent: AppSpacing.lg),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
