// ─── Domain Entity: Participant ──────────────────────────────────────────────
//
// Uses Google's stable `users/{userId}` identifier instead of email.
// Supports multiple sessions per participant (rejoin-safe).

class ParticipantEntity {
  /// "users/{userId}" for signed-in users, display name for anonymous.
  final String participantKey;
  final String displayName;
  final DateTime startTime;
  final DateTime? endTime; // null = currently in the meeting
  final int totalDurationMinutes;

  const ParticipantEntity({
    required this.participantKey,
    required this.displayName,
    required this.startTime,
    this.endTime,
    required this.totalDurationMinutes,
  });

  /// True when the participant has no end time (still inside the meeting).
  bool get isCurrentlyPresent => endTime == null;
}
