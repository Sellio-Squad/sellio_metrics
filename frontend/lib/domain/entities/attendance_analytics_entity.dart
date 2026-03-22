/// Attendance analytics entity — aggregated attendance data from backend.
library;

class AttendanceAnalyticsEntity {
  final int totalMeetings;
  final int totalAttendees;
  final int averageDurationMinutes;
  final int averageScore;
  final List<MostActiveParticipant> mostActiveParticipants;
  final List<AttendanceTrend> attendanceTrends;

  const AttendanceAnalyticsEntity({
    required this.totalMeetings,
    required this.totalAttendees,
    required this.averageDurationMinutes,
    required this.averageScore,
    required this.mostActiveParticipants,
    required this.attendanceTrends,
  });

  static const empty = AttendanceAnalyticsEntity(
    totalMeetings: 0,
    totalAttendees: 0,
    averageDurationMinutes: 0,
    averageScore: 0,
    mostActiveParticipants: [],
    attendanceTrends: [],
  );
}

class MostActiveParticipant {
  final String displayName;
  final String? email;
  final int meetingsAttended;
  final int totalMinutes;
  final int averageScore;

  const MostActiveParticipant({
    required this.displayName,
    this.email,
    required this.meetingsAttended,
    required this.totalMinutes,
    required this.averageScore,
  });
}

class AttendanceTrend {
  final String date;
  final int attendeeCount;
  final int averageDuration;

  const AttendanceTrend({
    required this.date,
    required this.attendeeCount,
    required this.averageDuration,
  });
}

/// Rate limit info from the backend.
class RateLimitEntity {
  final int remaining;
  final int limit;
  final String resetAt;
  final bool isLow;

  const RateLimitEntity({
    required this.remaining,
    required this.limit,
    required this.resetAt,
    required this.isLow,
  });

  static const empty = RateLimitEntity(
    remaining: 60,
    limit: 60,
    resetAt: '',
    isLow: false,
  );
}
