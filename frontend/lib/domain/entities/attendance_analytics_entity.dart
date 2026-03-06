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

  factory AttendanceAnalyticsEntity.fromJson(Map<String, dynamic> json) =>
      AttendanceAnalyticsEntity(
        totalMeetings: json['totalMeetings'] as int? ?? 0,
        totalAttendees: json['totalAttendees'] as int? ?? 0,
        averageDurationMinutes: json['averageDurationMinutes'] as int? ?? 0,
        averageScore: json['averageScore'] as int? ?? 0,
        mostActiveParticipants: (json['mostActiveParticipants'] as List? ?? [])
            .map(
              (e) => MostActiveParticipant.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        attendanceTrends: (json['attendanceTrends'] as List? ?? [])
            .map((e) => AttendanceTrend.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

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

  factory MostActiveParticipant.fromJson(Map<String, dynamic> json) =>
      MostActiveParticipant(
        displayName: json['displayName'] as String? ?? 'Unknown',
        email: json['email'] as String?,
        meetingsAttended: json['meetingsAttended'] as int? ?? 0,
        totalMinutes: json['totalMinutes'] as int? ?? 0,
        averageScore: json['averageScore'] as int? ?? 0,
      );
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

  factory AttendanceTrend.fromJson(Map<String, dynamic> json) =>
      AttendanceTrend(
        date: json['date'] as String? ?? '',
        attendeeCount: json['attendeeCount'] as int? ?? 0,
        averageDuration: json['averageDuration'] as int? ?? 0,
      );
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

  factory RateLimitEntity.fromJson(Map<String, dynamic> json) =>
      RateLimitEntity(
        remaining: json['remaining'] as int? ?? 0,
        limit: json['limit'] as int? ?? 60,
        resetAt: json['resetAt'] as String? ?? '',
        isLow: json['isLow'] as bool? ?? false,
      );

  static const empty = RateLimitEntity(
    remaining: 60,
    limit: 60,
    resetAt: '',
    isLow: false,
  );
}
