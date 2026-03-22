class MostActiveParticipantModel {
  final String displayName;
  final String? email;
  final int meetingsAttended;
  final int totalMinutes;
  final int averageScore;

  const MostActiveParticipantModel({
    required this.displayName,
    this.email,
    required this.meetingsAttended,
    required this.totalMinutes,
    required this.averageScore,
  });

  factory MostActiveParticipantModel.fromJson(Map<String, dynamic> json) =>
      MostActiveParticipantModel(
        displayName: json['displayName'] as String? ?? 'Unknown',
        email: json['email'] as String?,
        meetingsAttended: json['meetingsAttended'] as int? ?? 0,
        totalMinutes: json['totalMinutes'] as int? ?? 0,
        averageScore: json['averageScore'] as int? ?? 0,
      );
}

class AttendanceTrendModel {
  final String date;
  final int attendeeCount;
  final int averageDuration;

  const AttendanceTrendModel({
    required this.date,
    required this.attendeeCount,
    required this.averageDuration,
  });

  factory AttendanceTrendModel.fromJson(Map<String, dynamic> json) =>
      AttendanceTrendModel(
        date: json['date'] as String? ?? '',
        attendeeCount: json['attendeeCount'] as int? ?? 0,
        averageDuration: json['averageDuration'] as int? ?? 0,
      );
}

class RateLimitModel {
  final int remaining;
  final int limit;
  final String resetAt;
  final bool isLow;

  const RateLimitModel({
    required this.remaining,
    required this.limit,
    required this.resetAt,
    required this.isLow,
  });

  factory RateLimitModel.fromJson(Map<String, dynamic> json) => RateLimitModel(
        remaining: json['remaining'] as int? ?? 0,
        limit: json['limit'] as int? ?? 60,
        resetAt: json['resetAt'] as String? ?? '',
        isLow: json['isLow'] as bool? ?? false,
      );
}

class AttendanceAnalyticsModel {
  final int totalMeetings;
  final int totalAttendees;
  final int averageDurationMinutes;
  final int averageScore;
  final List<MostActiveParticipantModel> mostActiveParticipants;
  final List<AttendanceTrendModel> attendanceTrends;

  const AttendanceAnalyticsModel({
    required this.totalMeetings,
    required this.totalAttendees,
    required this.averageDurationMinutes,
    required this.averageScore,
    required this.mostActiveParticipants,
    required this.attendanceTrends,
  });

  factory AttendanceAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceAnalyticsModel(
      totalMeetings: json['totalMeetings'] as int? ?? 0,
      totalAttendees: json['totalAttendees'] as int? ?? 0,
      averageDurationMinutes: json['averageDurationMinutes'] as int? ?? 0,
      averageScore: json['averageScore'] as int? ?? 0,
      mostActiveParticipants: (json['mostActiveParticipants'] as List? ?? [])
          .map((e) => MostActiveParticipantModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      attendanceTrends: (json['attendanceTrends'] as List? ?? [])
          .map((e) => AttendanceTrendModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
