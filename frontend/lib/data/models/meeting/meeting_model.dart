class MeetingModel {
  final String id;
  final String title;
  final String spaceName;
  final String meetingUri;
  final String meetingCode;
  final DateTime createdAt;
  final int participantCount;

  const MeetingModel({
    required this.id,
    required this.title,
    required this.spaceName,
    required this.meetingUri,
    required this.meetingCode,
    required this.createdAt,
    required this.participantCount,
  });

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      spaceName: json['spaceName'] as String? ?? '',
      meetingUri: json['meetingUri'] as String? ?? '',
      meetingCode: json['meetingCode'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      participantCount: json['participantCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'spaceName': spaceName,
      'meetingUri': meetingUri,
      'meetingCode': meetingCode,
      'createdAt': createdAt.toIso8601String(),
      'participantCount': participantCount,
    };
  }
}
