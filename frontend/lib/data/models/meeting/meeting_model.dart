// ─── Data Model: Meeting ─────────────────────────────────────────────────────

import 'package:sellio_metrics/domain/entities/meeting_entity.dart';

class MeetingModel {
  final String id;
  final String title;
  final String spaceName;
  final String meetingUri;
  final String meetingCode;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int participantCount;
  final bool subscribed;

  const MeetingModel({
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

  factory MeetingModel.fromJson(Map<String, dynamic> json) {
    return MeetingModel(
      id:               json['id']               as String? ?? '',
      title:            json['title']             as String? ?? '',
      spaceName:        json['spaceName']          as String? ?? '',
      meetingUri:       json['meetingUri']         as String? ?? '',
      meetingCode:      json['meetingCode']        as String? ?? '',
      createdAt:        DateTime.tryParse(json['createdAt'] as String? ?? '')  ?? DateTime.now(),
      endedAt:          json['endedAt']  != null ? DateTime.tryParse(json['endedAt'] as String) : null,
      participantCount: json['participantCount']   as int?    ?? 0,
      subscribed:       json['subscribed']         as bool?   ?? true,
    );
  }

  MeetingEntity toEntity() => MeetingEntity(
    id:               id,
    title:            title,
    spaceName:        spaceName,
    meetingUri:       meetingUri,
    meetingCode:      meetingCode,
    createdAt:        createdAt,
    endedAt:          endedAt,
    participantCount: participantCount,
    subscribed:       subscribed,
  );
}
