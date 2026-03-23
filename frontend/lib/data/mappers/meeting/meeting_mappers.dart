import 'package:sellio_metrics/domain/entities/attendance_analytics_entity.dart';
import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/data/models/meeting/attendance_analytics_model.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/data/models/meeting/participant_model.dart';
import 'package:sellio_metrics/data/models/meeting/rate_limit_model.dart';

extension MeetingModelMapper on MeetingModel {
  MeetingEntity toEntity() {
    return MeetingEntity(
      id: id,
      title: title,
      spaceName: spaceName,
      meetingUri: meetingUri,
      meetingCode: meetingCode,
      createdAt: createdAt,
      participantCount: participantCount,
    );
  }
}
extension ParticipantModelMapper on ParticipantModel {
  ParticipantEntity toEntity() {
    return ParticipantEntity(
      displayName: displayName,
      email: email,
      joinTime: joinTime,
      leaveTime: leaveTime,
      durationMinutes: durationMinutes,
      attendanceScore: attendanceScore,
    );
  }
}

extension MostActiveParticipantModelMapper on MostActiveParticipantModel {
  MostActiveParticipant toEntity() {
    return MostActiveParticipant(
      displayName: displayName,
      email: email,
      meetingsAttended: meetingsAttended,
      totalMinutes: totalMinutes,
      averageScore: averageScore,
    );
  }
}

extension AttendanceTrendModelMapper on AttendanceTrendModel {
  AttendanceTrend toEntity() {
    return AttendanceTrend(
      date: date,
      attendeeCount: attendeeCount,
      averageDuration: averageDuration,
    );
  }
}

extension RateLimitModelMapper on RateLimitModel {
  RateLimitEntity toEntity() {
    return RateLimitEntity(
      remaining: remaining,
      limit: limit,
      resetAt: resetAt,
      isLow: isLow,
    );
  }
}

extension AttendanceAnalyticsModelMapper on AttendanceAnalyticsModel {
  AttendanceAnalyticsEntity toEntity() {
    return AttendanceAnalyticsEntity(
      totalMeetings: totalMeetings,
      totalAttendees: totalAttendees,
      averageDurationMinutes: averageDurationMinutes,
      averageScore: averageScore,
      mostActiveParticipants:
          mostActiveParticipants.map((p) => p.toEntity()).toList(),
      attendanceTrends: attendanceTrends.map((t) => t.toEntity()).toList(),
    );
  }
}
