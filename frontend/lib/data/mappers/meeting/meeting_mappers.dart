// ─── Meeting Domain Mappers ───────────────────────────────────────────────────
//
// NOTE: MeetingModel and ParticipantModel already include self-contained
// toEntity() methods. These extension methods are kept here only for code
// sites that use the extension syntax rather than the method syntax.

import 'package:sellio_metrics/domain/entities/meeting_entity.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/data/models/meeting/participant_model.dart';

extension MeetingModelMapper on MeetingModel {
  MeetingEntity toEntityEx() => toEntity();
}

extension ParticipantModelMapper on ParticipantModel {
  ParticipantEntity toEntityEx() => toEntity();
}
