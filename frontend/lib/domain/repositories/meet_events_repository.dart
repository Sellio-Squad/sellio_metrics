/// Meet Events Repository — Interface
///
/// Domain-level interface for real-time Meet event tracking.
/// Separate from MeetingsRepository (Single Responsibility).

import 'dart:async';
import 'package:sellio_metrics/domain/entities/meet_event_entity.dart';

abstract class MeetEventsRepository {
  /// Subscribe to Workspace Events for a meeting space.
  Future<Map<String, dynamic>> subscribe(String spaceName);

  /// Fetch recent events from the backend.
  Future<List<MeetEventEntity>> getEvents({int limit = 50});

  /// Connect to the SSE event stream. Returns a stream of parsed events.
  Stream<MeetEventEntity> connectStream({String? lastEventId});

  /// Disconnect from the SSE stream.
  void disconnectStream();

  /// Fetch active subscriptions.
  Future<List<Map<String, dynamic>>> getSubscriptions();
}
