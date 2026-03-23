import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/attendance_analytics_entity.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_auth_data_source.dart';
import 'package:sellio_metrics/data/datasources/meeting/meetings_data_source.dart';
import 'package:sellio_metrics/data/mappers/meeting/meeting_mappers.dart';
import 'package:sellio_metrics/data/models/meeting/participant_model.dart';

@LazySingleton(as: MeetingsRepository)
class MeetingsRepositoryImpl implements MeetingsRepository {
  final MeetingsDataSource _dataSource;
  final MeetAuthDataSource _authDataSource;

  MeetingsRepositoryImpl(this._dataSource, this._authDataSource);

  @override
  Future<MeetingEntity> createMeeting(String title) async {
    final model = await _dataSource.createMeeting(title);
    return model.toEntity();
  }

  @override
  Future<List<MeetingEntity>> getMeetings() async {
    final models = await _dataSource.fetchMeetings();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<MeetingDetailResult> getMeetingDetail(String id) async {
    final json = await _dataSource.fetchMeetingDetail(id);

    final meeting = MeetingEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      spaceName: json['spaceName'] as String? ?? '',
      meetingUri: json['meetingUri'] as String? ?? '',
      meetingCode: json['meetingCode'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      participantCount: json['participantCount'] as int? ?? 0,
    );
    final participants = (json['participants'] as List? ?? [])
        .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>).toEntity())
        .toList();

    return MeetingDetailResult(meeting: meeting, participants: participants);
  }

  @override
  Future<AttendanceResult> getAttendance(String meetingId) async {
    final json = await _dataSource.fetchAttendance(meetingId);

    final participants = (json['participants'] as List? ?? [])
        .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>).toEntity())
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
    final model = await _dataSource.fetchAnalytics();
    return model.toEntity();
  }

  @override
  Future<RateLimitEntity> getRateLimitStatus() async {
    final model = await _dataSource.fetchRateLimitStatus();
    return model.toEntity();
  }

  @override
  Future<bool> getAuthStatus() async {
    return _authDataSource.fetchAuthStatus();
  }

  @override
  Future<String?> getAuthUrl() async {
    return _authDataSource.fetchAuthUrl();
  }

  @override
  Future<void> logout() async {
    return _authDataSource.logout();
  }

  @override
  Future<void> endMeeting(String id) async {
    return _dataSource.endMeeting(id);
  }
}
