/// Participant entity — domain model for a meeting participant.
///
/// Attendance score is computed on the backend (weighted: presence 40%,
/// duration 35%, consistency 25%).

class ParticipantEntity {
  final String displayName;
  final String? email;
  final DateTime joinTime;
  final DateTime? leaveTime;
  final int durationMinutes;
  final int attendanceScore;

  const ParticipantEntity({
    required this.displayName,
    this.email,
    required this.joinTime,
    this.leaveTime,
    required this.durationMinutes,
    required this.attendanceScore,
  });

  /// Whether the participant is currently in the meeting (no leave time).
  bool get isCurrentlyPresent => leaveTime == null;
}
