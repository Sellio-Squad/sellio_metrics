// ─── Widget: Participant Row ──────────────────────────────────────────────────
//
// A single row in the participants list. Shows avatar, name, duration pill,
// join time, and live/left status badge.
// Hover shows a subtle background tint — no shadow.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';

class ParticipantRow extends StatefulWidget {
  final ParticipantEntity participant;

  const ParticipantRow({super.key, required this.participant});

  @override
  State<ParticipantRow> createState() => _ParticipantRowState();
}

class _ParticipantRowState extends State<ParticipantRow> {
  Timer? _timer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ParticipantRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.participant.isCurrentlyPresent) {
      _timer?.cancel();
    } else if (_timer == null || !_timer!.isActive) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    if (widget.participant.isCurrentlyPresent) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final isLive = widget.participant.isCurrentlyPresent;
    final formatter = DateFormat('h:mm a');

    final start = widget.participant.startTime;
    final end = widget.participant.endTime ?? DateTime.now();
    int currentDuration = end.difference(start).inMinutes.clamp(0, 9999);

    if (!isLive && widget.participant.totalDurationMinutes > 0) {
      currentDuration = widget.participant.totalDurationMinutes;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        // Only background tint on hover — no box-shadow
        duration: const Duration(milliseconds: 150),
        color: _isHovered ? scheme.surfaceLow : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 500;

            return Row(
              children: [
                // ── Avatar with green dot for live participants
                Stack(
                  children: [
                    SAvatar(
                      name: widget.participant.displayName,
                      size: SAvatarSize.medium,
                    ),
                    if (isLive)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: SellioColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),

                // ── Name + key
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.participant.displayName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.participant.participantKey,
                        style: AppTypography.caption.copyWith(
                          color: scheme.hint,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                if (!isCompact) ...[
                  // ── Duration pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.clock, size: 12, color: scheme.hint),
                        const SizedBox(width: 4),
                        Text(
                          currentDuration < 1
                              ? '< 1 min'
                              : '$currentDuration min',
                          style: AppTypography.caption.copyWith(
                            color: scheme.title,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // ── Time range
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isLive
                            ? 'In since ${formatter.format(start)}'
                            : widget.participant.endTime != null
                                ? '${formatter.format(start)} — ${formatter.format(widget.participant.endTime!)}'
                                : formatter.format(start),
                        style: AppTypography.caption.copyWith(
                          color: scheme.hint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ],

                // ── Status badge
                SizedBox(
                  width: 64,
                  child: isLive
                      ? SBadge(
                          label: l10n.live,
                          variant: SBadgeVariant.success,
                        )
                      : SBadge(
                          label: 'Left',
                          variant: SBadgeVariant.secondary,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
