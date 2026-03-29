// ─── Regular Meetings Section ─────────────────────────────────────────────────
//
// Shows manageable recurring team meeting schedules.
// Features:
//  • Data flows from MeetingsProvider (data layer)
//  • HuxBadge for recurrence labels
//  • Per-card delete button
//  • "Add Schedule" inline form via CreateSchedulePanel
//  • "Add all to calendar" bulk ICS download

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/utils/ics_generator.dart';
import 'package:sellio_metrics/core/utils/web_download.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/create_schedule_panel.dart';

class RegularMeetingsSection extends StatefulWidget {
  final List<RegularMeetingSchedule> meetings;

  const RegularMeetingsSection({super.key, required this.meetings});

  @override
  State<RegularMeetingsSection> createState() => _RegularMeetingsSectionState();
}

class _RegularMeetingsSectionState extends State<RegularMeetingsSection> {
  bool _showCreateForm = false;

  void _downloadAll(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Sellio Metrics//Team Meetings//EN');
    buffer.writeln('CALSCALE:GREGORIAN');

    for (final m in widget.meetings) {
      final eventContent = IcsGenerator.generate(
        title: m.title,
        description: m.description,
        startTime: m.startTime,
        duration: m.duration,
        location: 'Google Meet - https://meet.google.com',
        recurrenceRule: m.recurrenceRule,
      );
      final lines = eventContent.split('\n');
      bool inEvent = false;
      for (final line in lines) {
        if (line.trim() == 'BEGIN:VEVENT') inEvent = true;
        if (inEvent) buffer.writeln(line);
        if (line.trim() == 'END:VEVENT') inEvent = false;
      }
    }

    buffer.writeln('END:VCALENDAR');
    WebDownload.downloadFile(buffer.toString(), 'team_meetings.ics', 'text/calendar');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<MeetingsProvider>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(LucideIcons.calendarClock,
                    size: 18, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Schedule',
                      style: AppTypography.title.copyWith(
                        color: scheme.title,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.meetings.length} recurring meeting${widget.meetings.length != 1 ? 's' : ''}',
                      style:
                          AppTypography.caption.copyWith(color: scheme.hint),
                    ),
                  ],
                ),
              ),
              // ── Toolbar buttons
              if (widget.meetings.isNotEmpty)
                SButton(
                  variant: SButtonVariant.outline,
                  size: SButtonSize.small,
                  onPressed: () => _downloadAll(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.calendarPlus,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Add all to calendar',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              SButton(
                variant: _showCreateForm
                    ? SButtonVariant.ghost
                    : SButtonVariant.primary,
                size: SButtonSize.small,
                onPressed: () =>
                    setState(() => _showCreateForm = !_showCreateForm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showCreateForm
                          ? LucideIcons.x
                          : LucideIcons.plus,
                      size: 14,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(_showCreateForm ? 'Cancel' : 'Add Schedule'),
                  ],
                ),
              ),
            ],
          ),

          // ── Inline create form
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _showCreateForm
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: CreateSchedulePanel(
                      onCreate: (schedule) async {
                        final ok = await context
                            .read<MeetingsProvider>()
                            .createRegularMeeting(schedule);
                        if (ok && mounted) {
                          setState(() => _showCreateForm = false);
                        }
                        return ok;
                      },
                      onCancel: () =>
                          setState(() => _showCreateForm = false),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Loading indicator during schedule ops
          if (provider.isScheduleLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),

          if (widget.meetings.isEmpty && !_showCreateForm)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.calendarOff,
                        size: 36,
                        color: scheme.hint.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No schedules yet',
                      style: AppTypography.body.copyWith(color: scheme.hint),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Press "Add Schedule" to create your first recurring meeting.',
                      style: AppTypography.caption
                          .copyWith(color: scheme.hint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (widget.meetings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),

            // ── Grid of schedule cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 210,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                    ),
                    itemCount: widget.meetings.length,
                    itemBuilder: (context, index) {
                      return _ScheduleCard(meeting: widget.meetings[index]);
                    },
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.meetings.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _ScheduleCard(meeting: widget.meetings[index]);
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Schedule Card ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatefulWidget {
  final RegularMeetingSchedule meeting;
  const _ScheduleCard({required this.meeting});

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _isHovered = false;

  void _downloadIcs(BuildContext context) {
    final icsContent = IcsGenerator.generate(
      title: widget.meeting.title,
      description: widget.meeting.description,
      startTime: widget.meeting.startTime,
      duration: widget.meeting.duration,
      location: 'Google Meet - https://meet.google.com',
      recurrenceRule: widget.meeting.recurrenceRule,
    );
    final safeFilename =
        widget.meeting.title.replaceAll(' ', '_').toLowerCase();
    WebDownload.downloadFile(
        icsContent, '$safeFilename.ics', 'text/calendar');
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final scheme = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text(
          'Delete "${widget.meeting.title}"?',
          style: AppTypography.title.copyWith(color: scheme.title),
        ),
        content: Text(
          'This will remove the schedule from the list. This action cannot be undone.',
          style: AppTypography.body.copyWith(color: scheme.hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SButton(
            variant: SButtonVariant.primary,
            primaryColor: SellioColors.red,
            size: SButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<MeetingsProvider>().deleteRegularMeeting(widget.meeting.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final m = widget.meeting;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: scheme.surfaceLow,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: _isHovered
                ? m.accentColor.withValues(alpha: 0.3)
                : scheme.stroke,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: m.accentColor.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Accent line
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                gradient: LinearGradient(
                  colors: [
                    m.accentColor,
                    m.accentColor.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Header: icon + title + badge + delete
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: m.accentColor.withValues(alpha: 0.1),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Icon(m.icon, size: 16, color: m.accentColor),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: AppTypography.subtitle.copyWith(
                                  color: scheme.title,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.description,
                                style: AppTypography.caption.copyWith(
                                  color: scheme.body,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ── HuxBadge for recurrence
                            HuxBadge(
                              label: m.recurrenceLabel,
                              variant: HuxBadgeVariant.primary,
                              size: HuxBadgeSize.small,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            // ── Delete button
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _isHovered ? 1.0 : 0.0,
                              child: GestureDetector(
                                onTap: () => _confirmDelete(context),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: SellioColors.red
                                          .withValues(alpha: 0.08),
                                      borderRadius: AppRadius.smAll,
                                    ),
                                    child: Icon(
                                      LucideIcons.trash2,
                                      size: 13,
                                      color: SellioColors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // ── Info chips
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _InfoChip(
                          icon: LucideIcons.calendar,
                          text: m.dayTime,
                          color: m.accentColor,
                        ),
                        _InfoChip(
                          icon: LucideIcons.timer,
                          text: m.durationLabel,
                          color: m.accentColor,
                        ),
                      ],
                    ),

                    // ── Download ICS button
                    Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isHovered ? 1.0 : 0.6,
                        child: SButton(
                          variant: SButtonVariant.outline,
                          size: SButtonSize.small,
                          onPressed: () => _downloadIcs(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.download,
                                  size: 13, color: m.accentColor),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                AppLocalizations.of(context).meetingDownloadIcs,
                                style: TextStyle(
                                    color: m.accentColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Chip ────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: scheme.hint,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}