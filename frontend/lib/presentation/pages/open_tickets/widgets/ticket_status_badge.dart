import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/ticket_entity.dart';

class TicketStatusBadge extends StatelessWidget {
  final TicketHealthStatus status;
  final TicketSource source;
  final bool compact;

  const TicketStatusBadge({
    super.key,
    required this.status,
    this.source = TicketSource.issue,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    // Draft tickets always show as grey
    if (source == TicketSource.draft) {
      if (compact) {
        return Container(width: 8, height: 8,
          decoration: BoxDecoration(color: scheme.hint, shape: BoxShape.circle));
      }
      return _badge(scheme.hint.withValues(alpha: 0.12), scheme.hint,
          Icons.edit_note_rounded, 'Draft');
    }

    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      TicketHealthStatus.overdue => (
          scheme.red.withValues(alpha: 0.12), scheme.red,
          Icons.schedule_rounded, 'Overdue',
        ),
      TicketHealthStatus.noDeadline => (
          const Color(0xFFF5A623).withValues(alpha: 0.12), const Color(0xFFF5A623),
          Icons.warning_amber_rounded, 'No Deadline',
        ),
      TicketHealthStatus.healthy => (
          scheme.green.withValues(alpha: 0.12), scheme.green,
          Icons.check_circle_outline_rounded, 'On Track',
        ),
    };

    if (compact) {
      return Container(width: 8, height: 8,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle));
    }
    return _badge(bg, fg, icon, label);
  }

  Widget _badge(Color bg, Color fg, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
            style: AppTypography.caption.copyWith(
              color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}
