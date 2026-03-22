class ParticipantModel {
  final String displayName;
  final String email;
  final DateTime joinTime;
  final DateTime? leaveTime;
  final int durationMinutes;
  final int attendanceScore;

  const ParticipantModel({
    required this.displayName,
    required this.email,
    required this.joinTime,
    this.leaveTime,
    required this.durationMinutes,
    required this.attendanceScore,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      displayName: json['displayName'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      joinTime: DateTime.tryParse(json['joinTime'] as String? ?? '') ?? DateTime.now(),
      leaveTime: json['leaveTime'] != null ? DateTime.tryParse(json['leaveTime'] as String) : null,
      durationMinutes: json['durationMinutes'] as int? ?? 0,
      attendanceScore: json['attendanceScore'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'joinTime': joinTime.toIso8601String(),
      'leaveTime': leaveTime?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'attendanceScore': attendanceScore,
    };
  }
}
