// ─── Tab: Participants Live ───────────────────────────────────────────────────
//
// Shows only participants currently present in the meeting.
// Used as the "Live Now" tab content in MeetingDetailView.

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/participant_row.dart';

class ParticipantsLiveTab extends StatelessWidget {
  final List<ParticipantEntity> active;

  const ParticipantsLiveTab({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.radio,
              size: 40,
              color: scheme.hint.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No one is live right now',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Participants will appear here when they join.',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: active.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: scheme.stroke,
        indent: AppSpacing.lg,
        endIndent: AppSpacing.lg,
      ),
      itemBuilder: (_, i) => ParticipantRow(participant: active[i]),
    );
  }
}
