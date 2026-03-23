/// Meet Event Entity — domain model for real-time Google Meet events
/// received via Workspace Events + Pub/Sub.

class MeetEventEntity {
  final String id;
  final String eventType;
  final String label;
  final String spaceName;
  final String conferenceId;
  final MeetEventParticipantInfo? participantInfo;
  final DateTime timestamp;

  const MeetEventEntity({
    required this.id,
    required this.eventType,
    required this.label,
    required this.spaceName,
    required this.conferenceId,
    this.participantInfo,
    required this.timestamp,
  });

  factory MeetEventEntity.fromJson(Map<String, dynamic> json) =>
      MeetEventEntity(
        id: json['id'] as String? ?? '',
        eventType: json['eventType'] as String? ?? '',
        label: json['label'] as String? ?? '',
        spaceName: json['spaceName'] as String? ?? '',
        conferenceId: json['conferenceId'] as String? ?? '',
        participantInfo: json['participantInfo'] != null
            ? MeetEventParticipantInfo.fromJson(
                json['participantInfo'] as Map<String, dynamic>)
            : null,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );

  /// Whether this is a "positive" event (join/start) vs "negative" (leave/end).
  bool get isJoinOrStart =>
      eventType.contains('joined') || eventType.contains('started');

  /// Short human-friendly label without the full Google namespace.
  String get shortType {
    if (eventType.contains('joined')) return 'Joined';
    if (eventType.contains('left')) return 'Left';
    if (eventType.contains('started')) return 'Started';
    if (eventType.contains('ended')) return 'Ended';
    return label;
  }
}

class MeetEventParticipantInfo {
  final String displayName;
  final String email;

  const MeetEventParticipantInfo({
    required this.displayName,
    required this.email,
  });

  factory MeetEventParticipantInfo.fromJson(Map<String, dynamic> json) =>
      MeetEventParticipantInfo(
        displayName: json['displayName'] as String? ?? 'Unknown',
        email: json['email'] as String? ?? '',
      );
}
