// ─── Domain Entity: Meeting ──────────────────────────────────────────────────

class MeetingEntity {
  final String id;
  final String title;
  final String spaceName;
  final String meetingUri;
  final String meetingCode;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int participantCount;
  /// false when Pub/Sub subscription could not be created at meeting creation time.
  final bool subscribed;

  const MeetingEntity({
    required this.id,
    required this.title,
    required this.spaceName,
    required this.meetingUri,
    required this.meetingCode,
    required this.createdAt,
    this.endedAt,
    required this.participantCount,
    this.subscribed = true,
  });

  bool get isEnded => endedAt != null;
}
