// ─── Data Model: Participant ──────────────────────────────────────────────────
//
// Maps a single participant_session row from the backend.
// Uses participantKey (users/{userId}) instead of email.

import 'package:sellio_metrics/domain/entities/participant_entity.dart';

class ParticipantModel {
  final String participantKey;
  final String displayName;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalDurationMinutes;

  const ParticipantModel({
    required this.participantKey,
    required this.displayName,
    required this.startTime,
    this.endTime,
    required this.totalDurationMinutes,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      participantKey:      json['participantKey']      as String? ?? '',
      displayName:         json['displayName']         as String? ?? 'Unknown',
      startTime:           DateTime.tryParse(json['startTime']  as String? ?? '') ?? DateTime.now(),
      endTime:             json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
      totalDurationMinutes:json['totalDurationMinutes'] as int? ?? 0,
    );
  }

  ParticipantEntity toEntity() => ParticipantEntity(
    participantKey:       participantKey,
    displayName:          displayName,
    startTime:            startTime,
    endTime:              endTime,
    totalDurationMinutes: totalDurationMinutes,
  );
}
