import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/entities/user_entity.dart';

class PrTimelineEvent {
  final PrTimelineEventType type;
  final DateTime at;
  final UserEntity actor;
  final String? description;

  const PrTimelineEvent({
    required this.type,
    required this.at,
    required this.actor,
    this.description,
  });
}
