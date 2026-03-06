/// Meetings Repository Implementation
///
/// Implements [MeetingsRepository] using [MeetingsDataSource].
/// Maps raw JSON from the data source into domain entities.
library;

import '../../domain/entities/meeting_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/entities/attendance_analytics_entity.dart';
import '../../domain/repositories/meetings_repository.dart';
import '../datasources/meetings_data_source.dart';

class MeetingsRepositoryImpl implements MeetingsRepository {
  final MeetingsDataSource _dataSource;

  MeetingsRepositoryImpl({required MeetingsDataSource dataSource})
    : _dataSource = dataSource;

  @override
  Future<MeetingEntity> createMeeting(String title) async {
    final json = await _dataSource.createMeeting(title);
    return MeetingEntity.fromJson(json);
  }

  @override
  Future<List<MeetingEntity>> getMeetings() async {
    final list = await _dataSource.fetchMeetings();
    return list.map((json) => MeetingEntity.fromJson(json)).toList();
  }

  @override
  Future<MeetingDetailResult> getMeetingDetail(String id) async {
    final json = await _dataSource.fetchMeetingDetail(id);

    final meeting = MeetingEntity.fromJson(json);
    final participants = (json['participants'] as List? ?? [])
        .map((p) => ParticipantEntity.fromJson(p as Map<String, dynamic>))
        .toList();

    return MeetingDetailResult(meeting: meeting, participants: participants);
  }

  @override
  Future<AttendanceResult> getAttendance(String meetingId) async {
    final json = await _dataSource.fetchAttendance(meetingId);

    final participants = (json['participants'] as List? ?? [])
        .map((p) => ParticipantEntity.fromJson(p as Map<String, dynamic>))
        .toList();

    return AttendanceResult(
      meetingId: json['meetingId'] as String? ?? '',
      meetingTitle: json['meetingTitle'] as String? ?? '',
      meetingDate: json['meetingDate'] as String? ?? '',
      totalDurationMinutes: json['totalDurationMinutes'] as int? ?? 0,
      participants: participants,
    );
  }

  @override
  Future<AttendanceAnalyticsEntity> getAnalytics() async {
    final json = await _dataSource.fetchAnalytics();
    return AttendanceAnalyticsEntity.fromJson(json);
  }

  @override
  Future<RateLimitEntity> getRateLimitStatus() async {
    final json = await _dataSource.fetchRateLimitStatus();
    return RateLimitEntity.fromJson(json);
  }

  @override
  Future<bool> getAuthStatus() async {
    return _dataSource.fetchAuthStatus();
  }

  @override
  Future<String?> getAuthUrl() async {
    return _dataSource.fetchAuthUrl();
  }

  @override
  Future<void> logout() async {
    return _dataSource.logout();
  }

  @override
  Future<void> endMeeting(String id) async {
    return _dataSource.endMeeting(id);
  }
}
