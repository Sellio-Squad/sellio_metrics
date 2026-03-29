// ─── Domain Repository: Meetings ─────────────────────────────────────────────
//
// WebSocket-driven real-time tracking.
// Removed: attendance, analytics, rate-limit (YAGNI).

import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';

abstract class MeetingsRepository {
  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<bool> getAuthStatus();
  Future<String?> getAuthUrl();
  Future<void> logout();

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<MeetingEntity> createMeeting(String title);
  Future<List<MeetingEntity>> getMeetings();
  Future<MeetingDetailResult> getMeetingDetail(String id);
  Future<void> endMeeting(String id);

  // ─── Regular Meeting Schedules ───────────────────────────────────────────────

  /// Returns all configured recurring team meeting schedules.
  Future<List<RegularMeetingSchedule>> getRegularMeetings();

  /// Creates a new recurring meeting schedule and persists it.
  Future<RegularMeetingSchedule> createRegularMeeting(RegularMeetingSchedule schedule);

  /// Deletes a recurring meeting schedule by [id].
  Future<void> deleteRegularMeeting(String id);

  // ─── Real-time (WebSocket) ────────────────────────────────────────────────

  /// Opens a WebSocket to /api/meetings/:id/ws and emits [MeetingWsEvent]
  /// as they arrive. The stream closes when the meeting ends (code 1000).
  Stream<MeetingWsEvent> watchMeeting(String meetingId);

  /// Closes the active WebSocket for this meeting.
  void unwatchMeeting(String meetingId);
}

// ─── Result Types ─────────────────────────────────────────────────────────────

class MeetingDetailResult {
  final MeetingEntity meeting;
  final List<ParticipantEntity> participants;

  const MeetingDetailResult({required this.meeting, required this.participants});
}

// ─── WebSocket Event ──────────────────────────────────────────────────────────

enum MeetingWsEventType {
  participantJoined,
  participantLeft,
  meetingEnded;

  static MeetingWsEventType? fromJson(String? value) => switch (value) {
        'participant_joined' => participantJoined,
        'participant_left'   => participantLeft,
        'meeting_ended'      => meetingEnded,
        _                    => null,
      };
}

class MeetingWsEvent {
  final MeetingWsEventType type;
  final String meetingId;
  final String? participantKey;
  final String? displayName;
  final DateTime timestamp;

  const MeetingWsEvent({
    required this.type,
    required this.meetingId,
    this.participantKey,
    this.displayName,
    required this.timestamp,
  });

  factory MeetingWsEvent.fromJson(Map<String, dynamic> json) {
    return MeetingWsEvent(
      type:           MeetingWsEventType.fromJson(json['type'] as String?) ?? MeetingWsEventType.meetingEnded,
      meetingId:      json['meetingId'] as String? ?? '',
      participantKey: (json['participant'] as Map?)? ['participantKey'] as String?,
      displayName:    (json['participant'] as Map?)? ['displayName']    as String?,
      timestamp:      DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
