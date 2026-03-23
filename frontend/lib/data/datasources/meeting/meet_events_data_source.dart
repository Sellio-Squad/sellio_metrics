import 'dart:async';

abstract class MeetEventsDataSource {
  /// Subscribe to Workspace Events for a meeting space.
  Future<Map<String, dynamic>> subscribe(String spaceName);

  /// Fetch recent events (REST fallback).
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50});

  /// Fetch active subscriptions.
  Future<List<Map<String, dynamic>>> fetchSubscriptions();

  /// Connect to SSE stream. Returns a StreamController that emits parsed events.
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId});

  /// Disconnect SSE stream.
  void disconnectEventStream();
}
