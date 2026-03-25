import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meeting_watch_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';

import 'package:sellio_metrics/core/di/injection.dart';

class MeetingDetailView extends StatefulWidget {
  final String meetingId;

  const MeetingDetailView({super.key, required this.meetingId});

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

class _MeetingDetailViewState extends State<MeetingDetailView> {
  late final MeetingWatchProvider _watch;

  @override
  void initState() {
    super.initState();
    _watch = MeetingWatchProvider(
      repository: getIt<MeetingsRepository>(),
      meetingId:  widget.meetingId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetingsProvider>().selectMeeting(widget.meetingId);
    });
  }

  @override
  void dispose() {
    _watch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Consumer<MeetingsProvider>(
          builder: (context, meetingsProvider, _) {
            final meeting = meetingsProvider.selectedMeeting;
            if (meetingsProvider.isLoading && meeting == null) {
              return const LoadingScreen();
            }
            if (meeting == null) {
              return Center(child: Text(meetingsProvider.error ?? 'Unknown error'));
            }

            return AnimatedBuilder(
              animation: _watch,
              builder: (context, _) {
                // Instantly absorb existing snapshot
                _watch.initializeWithRestData(meetingsProvider.participants);

                final active  = _watch.active;
                final history = _watch.history;
                final formatter = DateFormat('MMM d, h:mm a');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Header ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meeting.title,
                                style: AppTypography.title.copyWith(
                                  fontSize: 24, color: scheme.title,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${formatter.format(meeting.createdAt)} • ${meeting.meetingCode}',
                                    style: AppTypography.body.copyWith(color: scheme.hint),
                                  ),
                                  if (_watch.isConnected) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(
                                        color: SellioColors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Live',
                                      style: AppTypography.caption.copyWith(
                                        color: SellioColors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SButton(
                              variant: SButtonVariant.ghost,
                              onPressed: () async {
                                final ok = await meetingsProvider.endMeeting(widget.meetingId);
                                if (ok && context.mounted) Navigator.of(context).pop();
                              },
                              child: meetingsProvider.isLoading
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('End Meeting'),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            IconButton(
                              icon: Icon(LucideIcons.x, color: scheme.hint),
                              onPressed: () {
                                meetingsProvider.clearSelection();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    Row(
                      children: [
                        _KpiCard(
                          label: 'Live Now',
                          value: active.length.toString(),
                          icon: LucideIcons.radio,
                          iconColor: active.isNotEmpty ? SellioColors.green : null,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _KpiCard(
                          label: 'Total Attended',
                          value: history.length.toString(),
                          icon: LucideIcons.users,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ─── Meeting ended banner ─────────────────────────────
                    if (_watch.meetingEnded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: SBadge(label: 'Meeting Ended', variant: SBadgeVariant.error),
                      ),

                    // ─── Participants list ────────────────────────────────
                    Text(
                      'Attendance History',
                      style: AppTypography.title.copyWith(fontSize: 18, color: scheme.title),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Expanded(
                      child: Builder(builder: (ctx) {
                        final list = List.of(history)..sort((a, b) {
                            if (a.isCurrentlyPresent && !b.isCurrentlyPresent) return -1;
                            if (!a.isCurrentlyPresent && b.isCurrentlyPresent) return 1;
                            return b.startTime.compareTo(a.startTime);
                        });
                        
                        if (list.isEmpty) {
                          return Center(
                            child: Text(
                              'No participants yet.',
                              style: AppTypography.body.copyWith(color: scheme.hint),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => Divider(color: scheme.stroke),
                          itemBuilder: (_, i) => _ParticipantRow(participant: list[i]),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color  = iconColor ?? scheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.stroke),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption.copyWith(color: scheme.hint)),
                const SizedBox(height: 4),
                Text(value, style: AppTypography.title.copyWith(fontSize: 24, color: scheme.title)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Participant Row ───────────────────────────────────────────────────────────

class _ParticipantRow extends StatefulWidget {
  final ParticipantEntity participant;

  const _ParticipantRow({required this.participant});

  @override
  State<_ParticipantRow> createState() => _ParticipantRowState();
}

class _ParticipantRowState extends State<_ParticipantRow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ParticipantRow oldWidget) {
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
    final scheme    = context.colors;
    final l10n      = AppLocalizations.of(context);
    final isLive    = widget.participant.isCurrentlyPresent;
    final formatter = DateFormat('h:mm a');
    
    final start = widget.participant.startTime;
    final end   = widget.participant.endTime ?? DateTime.now();
    int currentDuration = end.difference(start).inMinutes.clamp(0, 9999);
    
    // Fallback to the saved duration if it's already recorded strictly (for history logic)
    if (!isLive && widget.participant.totalDurationMinutes > 0) {
      currentDuration = widget.participant.totalDurationMinutes;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SAvatar(name: widget.participant.displayName, size: SAvatarSize.medium),
          const SizedBox(width: AppSpacing.lg),
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
                  style: AppTypography.caption.copyWith(color: scheme.hint),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentDuration < 1 ? '< 1 min' : '$currentDuration min',
                style: AppTypography.body.copyWith(color: scheme.title),
              ),
              const SizedBox(height: 2),
              Text(
                isLive
                    ? 'In since ${formatter.format(widget.participant.startTime)}'
                    : '${formatter.format(widget.participant.startTime)} — ${formatter.format(widget.participant.endTime!)}',
                style: AppTypography.caption.copyWith(color: scheme.hint),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xl),
          SizedBox(
            width: 72,
            child: isLive
                ? SBadge(label: l10n.live, variant: SBadgeVariant.success)
                : SBadge(label: 'Left', variant: SBadgeVariant.secondary),
          ),
        ],
      ),
    );
  }
}
