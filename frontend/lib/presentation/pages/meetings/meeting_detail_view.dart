import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/participant_entity.dart';
import '../../providers/meetings_provider.dart';
import '../../widgets/common/loading_screen.dart';

class MeetingDetailView extends StatefulWidget {
  final String meetingId;

  const MeetingDetailView({super.key, required this.meetingId});

  @override
  State<MeetingDetailView> createState() => _MeetingDetailViewState();
}

class _MeetingDetailViewState extends State<MeetingDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MeetingsProvider>().selectMeeting(widget.meetingId);
      context.read<MeetingsProvider>().loadAttendance(widget.meetingId);
    });
  }

  @override
  void dispose() {
    // We cannot easily clear the provider from here without context issues on pop,
    // so we handle clearing optionally or keep it cached.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          builder: (context, provider, _) {
            final meeting = provider.selectedMeeting;
            final isLiveLoading = provider.isLoading && meeting == null;
            final attendance = provider.attendance;

            // Note: In a real app we might combine live participants with historical attendance.
            // For now we'll prefer the detailed attendance records if they are loaded.
            final participants =
                attendance?.participants ?? provider.participants;

            if (isLiveLoading) {
              return const LoadingScreen();
            }

            if (meeting == null) {
              return Center(child: Text(provider.error ?? 'Unknown error'));
            }

            final formatter = DateFormat('MMM d, h:mm a');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              fontSize: 24,
                              color: scheme.title,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatter.format(meeting.createdAt)} • ${meeting.meetingCode}',
                            style: AppTypography.body.copyWith(
                              color: scheme.hint,
                            ),
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
                            final success = await provider.endMeeting(
                              widget.meetingId,
                            );
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: provider.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('End Meeting'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        IconButton(
                          icon: Icon(LucideIcons.x, color: scheme.hint),
                          onPressed: () {
                            provider.clearSelection();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                // KPIs
                Row(
                  children: [
                    _KpiCard(
                      label: l10n.participantsCount,
                      value: participants.length.toString(),
                      icon: LucideIcons.users,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    _KpiCard(
                      label: attendance != null
                          ? 'Total Duration'
                          : 'Live Status',
                      value: attendance != null
                          ? '${attendance.totalDurationMinutes} min'
                          : 'Ongoing',
                      icon: LucideIcons.clock,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),

                Text(
                  l10n.participantsCount,
                  style: AppTypography.title.copyWith(
                    fontSize: 20,
                    color: scheme.title,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Expanded(
                  child: participants.isEmpty
                      ? Center(
                          child: Text(
                            'No participants yet.',
                            style: AppTypography.body.copyWith(
                              color: scheme.hint,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: participants.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: scheme.stroke),
                          itemBuilder: (context, index) {
                            return _ParticipantRow(
                              participant: participants[index],
                            );
                          },
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
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
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: scheme.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.lg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(color: scheme.hint),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.title.copyWith(
                    fontSize: 24,
                    color: scheme.title,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final ParticipantEntity participant;

  const _ParticipantRow({required this.participant});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isLive = participant.isCurrentlyPresent;

    final joinFormatter = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SAvatar(name: participant.displayName, size: SAvatarSize.medium),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                ),
                if (participant.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    participant.email!,
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                ],
              ],
            ),
          ),

          // Times
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${participant.durationMinutes} min',
                style: AppTypography.body.copyWith(color: scheme.title),
              ),
              const SizedBox(height: 2),
              Text(
                '${joinFormatter.format(participant.joinTime)} — ${isLive ? 'Now' : joinFormatter.format(participant.leaveTime!)}',
                style: AppTypography.caption.copyWith(color: scheme.hint),
              ),
            ],
          ),

          const SizedBox(width: AppSpacing.xl),

          // Score / Live Badge
          SizedBox(
            width: 80,
            child: isLive
                ? SBadge(label: l10n.live, variant: SBadgeVariant.success)
                : SBadge(
                    label: '${participant.attendanceScore}%',
                    variant: _getScoreVariant(participant.attendanceScore),
                  ),
          ),
        ],
      ),
    );
  }

  SBadgeVariant _getScoreVariant(int score) {
    if (score >= 90) return SBadgeVariant.success;
    if (score >= 70) return SBadgeVariant.primary;
    return SBadgeVariant.error;
  }
}
