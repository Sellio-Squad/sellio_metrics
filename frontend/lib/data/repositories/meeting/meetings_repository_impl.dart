// ─── Data Repository Impl: Meetings ──────────────────────────────────────────

import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_auth_data_source.dart';
import 'package:sellio_metrics/data/datasources/meeting/meetings_data_source.dart';
import 'package:sellio_metrics/data/models/meeting/participant_model.dart';

@LazySingleton(as: MeetingsRepository)
class MeetingsRepositoryImpl implements MeetingsRepository {
  final MeetingsDataSource _dataSource;
  final MeetAuthDataSource _authDataSource;

  MeetingsRepositoryImpl(this._dataSource, this._authDataSource);

  // ─── Auth ────────────────────────────────────────────────────────────────

  @override
  Future<bool> getAuthStatus() => _authDataSource.fetchAuthStatus();

  @override
  Future<String?> getAuthUrl() => _authDataSource.fetchAuthUrl();

  @override
  Future<void> logout() => _authDataSource.logout();

  // ─── CRUD ─────────────────────────────────────────────────────────────────

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
      id:               json['id']              as String? ?? '',
      title:            json['title']            as String? ?? '',
      spaceName:        json['spaceName']         as String? ?? '',
      meetingUri:       json['meetingUri']        as String? ?? '',
      meetingCode:      json['meetingCode']       as String? ?? '',
      createdAt:        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      endedAt:          json['endedAt']  != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      participantCount: json['participantCount']  as int?    ?? 0,
      subscribed:       json['subscribed']        as bool?   ?? true,
    );

    final participants = (json['participants'] as List? ?? [])
        .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>).toEntity())
        .toList();

    return MeetingDetailResult(meeting: meeting, participants: participants);
  }

  @override
  Future<void> endMeeting(String id) => _dataSource.endMeeting(id);

  // ─── Real-time (WebSocket) ────────────────────────────────────────────────

  @override
  Stream<MeetingWsEvent> watchMeeting(String meetingId) =>
      _dataSource.watchMeeting(meetingId);

  @override
  void unwatchMeeting(String meetingId) => _dataSource.unwatchMeeting(meetingId);
}
