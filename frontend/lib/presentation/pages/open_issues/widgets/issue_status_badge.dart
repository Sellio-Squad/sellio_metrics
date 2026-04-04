import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/issue_entity.dart';

class IssueStatusBadge extends StatelessWidget {
  final IssueHealthStatus status;
  final bool compact;

  const IssueStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      IssueHealthStatus.overdue => (
          scheme.red.withValues(alpha: 0.12),
          scheme.red,
          Icons.schedule_rounded,
          'Overdue',
        ),
      IssueHealthStatus.noDeadline => (
          const Color(0xFFF5A623).withValues(alpha: 0.12),
          const Color(0xFFF5A623),
          Icons.warning_amber_rounded,
          'No Deadline',
        ),
      IssueHealthStatus.healthy => (
          scheme.green.withValues(alpha: 0.12),
          scheme.green,
          Icons.check_circle_outline_rounded,
          'Healthy',
        ),
    };

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: fg,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
