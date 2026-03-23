/// Meetings Domain Repository — Interface
///
/// Separate from MetricsRepository to follow the Single Responsibility
/// Principle. Handles only meeting-related data operations.

import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/entities/attendance_analytics_entity.dart';

abstract class MeetingsRepository {
  /// Create a new meeting and return the created entity.
  Future<MeetingEntity> createMeeting(String title);

  /// List all tracked meetings.
  Future<List<MeetingEntity>> getMeetings();

  /// Get meeting details with the participant list.
  Future<MeetingDetailResult> getMeetingDetail(String id);

  /// Get attendance records with scores for a specific meeting.
  Future<AttendanceResult> getAttendance(String meetingId);

  /// Get aggregated attendance analytics across all meetings.
  Future<AttendanceAnalyticsEntity> getAnalytics();

  /// Get Google Meet API rate limit status.
  Future<RateLimitEntity> getRateLimitStatus();

  /// Check if the backend holds a valid Google Meet OAuth token.
  Future<bool> getAuthStatus();

  /// Gets the OAuth sign-in URL.
  Future<String?> getAuthUrl();

  /// Clears the backend's Google Meet OAuth token.
  Future<void> logout();

  /// Ends an active Google Meeting
  Future<void> endMeeting(String id);
}

/// Combines meeting info + participants.
class MeetingDetailResult {
  final MeetingEntity meeting;
  final List<ParticipantEntity> participants;

  const MeetingDetailResult({
    required this.meeting,
    required this.participants,
  });
}

/// Attendance record for a meeting.
class AttendanceResult {
  final String meetingId;
  final String meetingTitle;
  final String meetingDate;
  final int totalDurationMinutes;
  final List<ParticipantEntity> participants;

  const AttendanceResult({
    required this.meetingId,
    required this.meetingTitle,
    required this.meetingDate,
    required this.totalDurationMinutes,
    required this.participants,
  });
}
