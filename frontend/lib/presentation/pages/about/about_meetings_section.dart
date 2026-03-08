/// Sellio Metrics — About Meetings Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/utils/ics_generator.dart';
import '../../../core/utils/web_download.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import 'about_section_header.dart';

class AboutMeetingsSection extends StatelessWidget {
  const AboutMeetingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Using placeholder dates but mapping them to correct names/times
    final now = DateTime.now();
    // Daily Standup: 10:00 AM
    final standupTime = DateTime(now.year, now.month, now.day, 10, 0);
    // Sprint Planning: Sunday, 11:00 AM
    final nextSunday = _getNextDayOfWeek(now, DateTime.sunday);
    final planningTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 11, 0);
    // Sprint Retrospective: Thursday, 3:00 PM
    final nextThursday = _getNextDayOfWeek(now, DateTime.thursday);
    final retroTime = DateTime(nextThursday.year, nextThursday.month, nextThursday.day, 15, 0);
    // Code Review Session: Tuesday, 2:00 PM
    final nextTuesday = _getNextDayOfWeek(now, DateTime.tuesday);
    final reviewTime = DateTime(nextTuesday.year, nextTuesday.month, nextTuesday.day, 14, 0);

    final meetings = [
      _MeetingInfo(
        title: l10n.meetingDailyStandup,
        description: l10n.meetingDailyStandupDesc,
        dayTime: 'Mon–Fri, 10:00 AM', // Custom string since it spans multiple days
        durationLabel: l10n.duration15Min,
        recurrenceLabel: l10n.meetingWeekly,
        icon: Icons.sync_alt,
        startTime: standupTime,
        duration: const Duration(minutes: 15),
        recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      ),
      _MeetingInfo(
        title: l10n.meetingSprintPlanning,
        description: l10n.meetingSprintPlanningDesc,
        dayTime: 'Sunday, 11:00 AM',
        durationLabel: l10n.duration1Hour,
        recurrenceLabel: l10n.meetingBiweekly,
        icon: Icons.calendar_today,
        startTime: planningTime,
        duration: const Duration(hours: 1),
        recurrenceRule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=SU',
      ),
      _MeetingInfo(
        title: l10n.meetingCodeReview,
        description: l10n.meetingCodeReviewDesc,
        dayTime: 'Tuesday, 2:00 PM',
        durationLabel: l10n.duration1Hour,
        recurrenceLabel: l10n.meetingWeekly,
        icon: Icons.code,
        startTime: reviewTime,
        duration: const Duration(hours: 1),
        recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU',
      ),
      _MeetingInfo(
        title: l10n.meetingRetrospective,
        description: l10n.meetingRetrospectiveDesc,
        dayTime: 'Thursday, 3:00 PM',
        durationLabel: l10n.duration45Min,
        recurrenceLabel: l10n.meetingBiweekly,
        icon: Icons.reviews_outlined,
        startTime: retroTime,
        duration: const Duration(minutes: 45),
        recurrenceRule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TH',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AboutSectionHeader(
          title: l10n.aboutMeetings,
          icon: Icons.event_note,
        ),
        const SizedBox(height: AppSpacing.lg),
        _MeetingTimeline(meetings: meetings),
      ],
    );
  }

  DateTime _getNextDayOfWeek(DateTime from, int weekday) {
    int daysToAdd = weekday - from.weekday;
    if (daysToAdd <= 0) {
      daysToAdd += 7;
    }
    return from.add(Duration(days: daysToAdd));
  }
}

class _MeetingTimeline extends StatelessWidget {
  final List<_MeetingInfo> meetings;

  const _MeetingTimeline({required this.meetings});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final isLast = index == meetings.length - 1;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Timeline connector line
            if (!isLast)
              Positioned(
                top: 32, // Start below the dot
                bottom: -AppSpacing.sm, // Connect down to the next dot
                left: 15, // Centered in the 32px wide column
                width: 2,
                child: Container(
                  color: context.colors.stroke,
                ),
              ),
            
            // Content Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dot
                SizedBox(
                  width: 32,
                  child: _TimelineDot(icon: meeting.icon),
                ),
                const SizedBox(width: AppSpacing.md),
                
                // Meeting Details Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: _MeetingCard(meeting: meeting),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TimelineDot extends StatelessWidget {
  final IconData icon;

  const _TimelineDot({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: scheme.primaryVariant,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 16,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final _MeetingInfo meeting;

  const _MeetingCard({required this.meeting});

  void _downloadIcs(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icsContent = IcsGenerator.generate(
      title: meeting.title,
      description: meeting.description,
      startTime: meeting.startTime,
      duration: meeting.duration,
      location: '${l10n.locationGoogleMeet} - https://meet.google.com/naa-qwff-pbi',
      recurrenceRule: meeting.recurrenceRule,
    );

    final safeFilename = meeting.title.replaceAll(' ', '_').toLowerCase();
    WebDownload.downloadFile(icsContent, '$safeFilename.ics', 'text/calendar');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    // Dynamic layout handling for web
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final cardContent = Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: AppTypography.subtitle.copyWith(color: scheme.title),
                    ),
                  ),
                  if (!isCompact)
                    SBadge(
                      label: meeting.recurrenceLabel,
                      variant: SBadgeVariant.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                meeting.description,
                style: AppTypography.body.copyWith(color: scheme.body),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InfoChip(icon: Icons.schedule, text: meeting.dayTime),
                  _InfoChip(icon: Icons.timer_outlined, text: meeting.durationLabel),
                  _InfoChip(icon: Icons.link, text: l10n.locationGoogleMeet),
                  if (isCompact)
                    SBadge(
                      label: meeting.recurrenceLabel,
                      variant: SBadgeVariant.primary,
                    ),
                ],
              ),
            ],
          ),
        );

        if (isCompact) {
          // Stack the button below the card
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cardContent,
              const SizedBox(height: AppSpacing.sm),
              SButton(
                variant: SButtonVariant.outline,
                size: SButtonSize.small,
                onPressed: () => _downloadIcs(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_available, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(l10n.meetingDownloadIcs),
                  ],
                ),
              ),
            ],
          );
        }

        // Side-by-side layout
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cardContent),
            const SizedBox(width: AppSpacing.md),
            SButton(
              variant: SButtonVariant.outline,
              size: SButtonSize.small,
              onPressed: () => _downloadIcs(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(l10n.meetingDownloadIcs),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.hint),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.caption.copyWith(color: scheme.hint),
        ),
      ],
    );
  }
}

class _MeetingInfo {
  final String title;
  final String description;
  final String dayTime;
  final String durationLabel;
  final String recurrenceLabel;
  final IconData icon;
  final DateTime startTime;
  final Duration duration;
  final String recurrenceRule;

  const _MeetingInfo({
    required this.title,
    required this.description,
    required this.dayTime,
    required this.durationLabel,
    required this.recurrenceLabel,
    required this.icon,
    required this.startTime,
    required this.duration,
    required this.recurrenceRule,
  });
}
