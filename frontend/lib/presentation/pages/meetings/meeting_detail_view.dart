// ─── Meeting Detail View ──────────────────────────────────────────────────────
//
// Thin orchestrator that composes:
//   • MeetingHeroCard
//   • KpiRow
//   • HuxTabs → Live / History / Reports
//
// All heavy UI logic lives in the widgets/ sub-directory.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hux/hux.dart' hide DateFormat;
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meeting_watch_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/meeting_hero_card.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/kpi_row.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/participants_live_tab.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/participants_history_tab.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/attendance_report_tab.dart';

class MeetingDetailView extends StatefulWidget {
  final String meetingId;
  final VoidCallback onBack;

  const MeetingDetailView({
    super.key,
    required this.meetingId,
    required this.onBack,
  });

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
      meetingId: widget.meetingId,
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

  int _calculateAverageDuration(List<ParticipantEntity> history) {
    if (history.isEmpty) return 0;
    int total = 0;
    for (final p in history) {
      final end = p.endTime ?? DateTime.now();
      total += end.difference(p.startTime).inMinutes.clamp(0, 9999);
    }
    return (total / history.length).round();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingsProvider>(
      builder: (context, meetingsProvider, _) {
        final meeting = meetingsProvider.selectedMeeting;

        if (meetingsProvider.isLoading && meeting == null) {
          return const LoadingScreen();
        }
        if (meeting == null) {
          return _ErrorState(
            error: meetingsProvider.error ?? 'Unknown error',
            onBack: widget.onBack,
          );
        }

        return AnimatedBuilder(
          animation: _watch,
          builder: (context, _) {
            _watch.initializeWithRestData(meetingsProvider.participants);

            final active = _watch.active;
            final history = _watch.history;
            final formatter = DateFormat('MMM d, yyyy · h:mm a');

            return Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero Card
                      MeetingHeroCard(
                        title: meeting.title,
                        meetingCode: meeting.meetingCode,
                        createdAt: formatter.format(meeting.createdAt),
                        meetingUri: meeting.meetingUri,
                        isConnected: _watch.isConnected,
                        meetingEnded: _watch.meetingEnded,
                        isLoading: meetingsProvider.isLoading,
                        onEndMeeting: () async {
                          final ok = await meetingsProvider
                              .endMeeting(widget.meetingId);
                          if (ok && context.mounted) widget.onBack();
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── KPI Row
                      KpiRow(
                        activeCount: active.length,
                        totalCount: history.length,
                        averageDuration: _calculateAverageDuration(history),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Meeting ended banner
                      if (_watch.meetingEnded) _MeetingEndedBanner(),

                      // ── Participants with tabs
                      _ParticipantsTabbedSection(
                        active: active,
                        history: history,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Participants Tabbed Section ──────────────────────────────────────────────

class _ParticipantsTabbedSection extends StatelessWidget {
  final List<ParticipantEntity> active;
  final List<ParticipantEntity> history;

  const _ParticipantsTabbedSection({
    required this.active,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Use Hux tabs directly since design_system barrel only exports LucideIcons from hux
      child: HuxTabs(
        variant: HuxTabVariant.default_,
        size: HuxTabSize.medium,
        tabs: [
          HuxTabItem(
            label: 'Live Now',
            icon: LucideIcons.radio,
            badge: active.isNotEmpty
                ? HuxBadge(
                    label: '${active.length}',
                    variant: HuxBadgeVariant.success,
                    size: HuxBadgeSize.small,
                  )
                : null,
            content: ParticipantsLiveTab(active: active),
          ),
          HuxTabItem(
            label: 'History',
            icon: LucideIcons.history,
            badge: history.isNotEmpty
                ? HuxBadge(
                    label: '${history.length}',
                    variant: HuxBadgeVariant.secondary,
                    size: HuxBadgeSize.small,
                  )
                : null,
            content: ParticipantsHistoryTab(history: history),
          ),
          HuxTabItem(
            label: 'Reports',
            icon: LucideIcons.barChart2,
            content: AttendanceReportTab(history: history),
          ),
        ],
      ),
    );
  }
}

// ─── Meeting Ended Banner ─────────────────────────────────────────────────────

class _MeetingEndedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SellioColors.red.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: SellioColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: SellioColors.red.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(
              LucideIcons.videoOff,
              size: 16,
              color: SellioColors.red,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Ended',
                  style: AppTypography.body.copyWith(
                    color: SellioColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This meeting has ended. The attendance data below is the final record.',
                  style: AppTypography.caption.copyWith(
                    color: SellioColors.red.withValues(alpha: 0.8),
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

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onBack;

  const _ErrorState({required this.error, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: SellioColors.red.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertCircle,
                size: 40,
                color: SellioColors.red,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Something went wrong',
              style: AppTypography.title.copyWith(
                color: scheme.title,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.body.copyWith(color: scheme.hint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SButton(
              variant: SButtonVariant.outline,
              onPressed: onBack,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.arrowLeft, size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Text('Back to Meetings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}