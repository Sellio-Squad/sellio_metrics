// ─── Domain Entity: Attendance Report ─────────────────────────────────────────
//
// Client-side computed report derived from a list of ParticipantEntity.
// No network call — all aggregation happens in the presentation layer.

import 'package:sellio_metrics/domain/entities/participant_entity.dart';

/// A single participant's aggregated attendance across a meeting.
class AttendeeStats {
  final String participantKey;
  final String displayName;
  final int totalMinutes;
  final int sessionCount;

  const AttendeeStats({
    required this.participantKey,
    required this.displayName,
    required this.totalMinutes,
    required this.sessionCount,
  });
}

/// Full attendance report derived from participant history.
class AttendanceReport {
  final int totalUniqueParticipants;
  final int averageDurationMinutes;
  final AttendeeStats? topAttendee;

  /// Participants sorted by most total minutes (desc).
  final List<AttendeeStats> leaderboard;

  const AttendanceReport({
    required this.totalUniqueParticipants,
    required this.averageDurationMinutes,
    this.topAttendee,
    required this.leaderboard,
  });

  /// Build a report from a flat list of participant presence records.
  factory AttendanceReport.fromParticipants(List<ParticipantEntity> history) {
    if (history.isEmpty) {
      return const AttendanceReport(
        totalUniqueParticipants: 0,
        averageDurationMinutes: 0,
        leaderboard: [],
      );
    }

    // Group by participantKey
    final Map<String, AttendeeStats> grouped = {};
    for (final p in history) {
      final duration = (p.endTime ?? DateTime.now())
          .difference(p.startTime)
          .inMinutes
          .clamp(0, 9999);

      if (grouped.containsKey(p.participantKey)) {
        final existing = grouped[p.participantKey]!;
        grouped[p.participantKey] = AttendeeStats(
          participantKey: p.participantKey,
          displayName: p.displayName,
          totalMinutes: existing.totalMinutes + duration,
          sessionCount: existing.sessionCount + 1,
        );
      } else {
        grouped[p.participantKey] = AttendeeStats(
          participantKey: p.participantKey,
          displayName: p.displayName,
          totalMinutes: duration,
          sessionCount: 1,
        );
      }
    }

    final leaderboard = grouped.values.toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    final totalMinutes =
        leaderboard.fold<int>(0, (sum, a) => sum + a.totalMinutes);
    final avgMinutes =
        leaderboard.isEmpty ? 0 : (totalMinutes / leaderboard.length).round();

    return AttendanceReport(
      totalUniqueParticipants: leaderboard.length,
      averageDurationMinutes: avgMinutes,
      topAttendee: leaderboard.isNotEmpty ? leaderboard.first : null,
      leaderboard: leaderboard,
    );
  }
}
