/// PR Ticket Link Section
///
/// Detects and displays linked tickets (Jira, GitHub issues).
/// Shows a warning if no ticket is detected.
library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/pr_entity.dart';
import '../../../../domain/services/pr_analysis_service.dart';

class PrTicketLinkSection extends StatelessWidget {
  final PrEntity pr;

  const PrTicketLinkSection({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final ticketId = PrAnalysisService.extractTicketId(pr);

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
              Icon(Icons.link_outlined, size: 16, color: scheme.hint),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Ticket Link',
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ticketId != null
              ? _LinkedTicket(ticketId: ticketId, scheme: scheme)
              : _NoTicketWarning(scheme: scheme),
        ],
      ),
    );
  }
}

class _LinkedTicket extends StatelessWidget {
  final String ticketId;
  final dynamic scheme;

  const _LinkedTicket({required this.ticketId, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.green.withValues(alpha: 0.08),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: scheme.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: scheme.green),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linked Ticket',
                  style: AppTypography.caption.copyWith(
                    color: scheme.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  ticketId,
                  style: AppTypography.body.copyWith(
                    color: scheme.title,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
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

class _NoTicketWarning extends StatelessWidget {
  final dynamic scheme;

  const _NoTicketWarning({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: SellioColors.amber.withValues(alpha: 0.06),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: SellioColors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: SellioColors.amber,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No ticket linked',
                  style: AppTypography.caption.copyWith(
                    color: SellioColors.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Consider linking to a Jira or GitHub issue for traceability.',
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
