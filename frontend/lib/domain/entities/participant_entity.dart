/// Participant entity — domain model for a meeting participant.
///
/// Attendance score is computed on the backend (weighted: presence 40%,
/// duration 35%, consistency 25%).
library;

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

  factory ParticipantEntity.fromJson(Map<String, dynamic> json) =>
      ParticipantEntity(
        displayName: json['displayName'] as String? ?? 'Unknown',
        email: json['email'] as String?,
        joinTime:
            DateTime.tryParse(json['joinTime'] as String? ?? '') ??
            DateTime.now(),
        leaveTime: json['leaveTime'] != null
            ? DateTime.tryParse(json['leaveTime'] as String)
            : null,
        durationMinutes: json['durationMinutes'] as int? ?? 0,
        attendanceScore: json['attendanceScore'] as int? ?? 0,
      );

  /// Whether the participant is currently in the meeting (no leave time).
  bool get isCurrentlyPresent => leaveTime == null;
}
