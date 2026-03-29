// ─── Tab: Attendance Report ───────────────────────────────────────────────────
//
// Shows aggregated attendance stats: leaderboard, top attendee, avg duration.
// All data is computed client-side from participant history via AttendanceReport.

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/attendance_report_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';

class AttendanceReportTab extends StatelessWidget {
  final List<ParticipantEntity> history;

  const AttendanceReportTab({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final report = AttendanceReport.fromParticipants(history);

    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.barChart2,
              size: 40,
              color: scheme.hint.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No attendance data yet',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary stat cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final cards = [
                _StatCard(
                  label: 'Unique Attendees',
                  value: '${report.totalUniqueParticipants}',
                  icon: LucideIcons.users,
                  color: scheme.primary,
                ),
                _StatCard(
                  label: 'Avg Time per Person',
                  value: report.averageDurationMinutes < 1
                      ? '< 1 min'
                      : '${report.averageDurationMinutes} min',
                  icon: LucideIcons.clock,
                  color: const Color(0xFF0EA5E9),
                ),
                if (report.topAttendee != null)
                  _StatCard(
                    label: 'Most Active',
                    value: report.topAttendee!.displayName.split(' ').first,
                    icon: LucideIcons.trophy,
                    color: const Color(0xFFF59E0B),
                  ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1)
                        const SizedBox(width: AppSpacing.md),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1)
                      const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Leaderboard
          Text(
            'Attendance Leaderboard',
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...report.leaderboard.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final attendee = entry.value;
            return _LeaderboardRow(
              rank: rank,
              attendee: attendee,
              isTop: rank == 1,
            );
          }),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.title.copyWith(
                    color: scheme.title,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard Row ──────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final AttendeeStats attendee;
  final bool isTop;

  const _LeaderboardRow({
    required this.rank,
    required this.attendee,
    required this.isTop,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final rankColor = isTop ? const Color(0xFFF59E0B) : scheme.hint;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isTop
            ? const Color(0xFFF59E0B).withValues(alpha: 0.05)
            : scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isTop
              ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
              : scheme.stroke,
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '#$rank',
              style: AppTypography.caption.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Avatar
          SAvatar(
            name: attendee.displayName,
            size: SAvatarSize.small,
          ),
          const SizedBox(width: AppSpacing.sm),

          // Name + sessions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attendee.displayName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${attendee.sessionCount} session${attendee.sessionCount > 1 ? 's' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Total time
          Text(
            attendee.totalMinutes < 1
                ? '< 1 min'
                : '${attendee.totalMinutes} min',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: isTop ? const Color(0xFFF59E0B) : scheme.title,
            ),
          ),
        ],
      ),
    );
  }
}
