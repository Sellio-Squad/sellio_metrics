/// Meet Events Data Source — HTTP + SSE communication with backend.
///
/// Provides methods for subscriptions, event listing, and SSE streaming.
/// Uses dart:html EventSource for real-time updates in Flutter Web.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ─── Abstract Interface ─────────────────────────────────────

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

// ─── Remote Implementation ──────────────────────────────────

class RemoteMeetEventsDataSource implements MeetEventsDataSource {
  final String baseUrl;
  final http.Client _client;

  html.EventSource? _eventSource;
  StreamController<Map<String, dynamic>>? _streamController;

  RemoteMeetEventsDataSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) async {
    final url = Uri.parse('$baseUrl/api/meet-events/subscribe');
    debugPrint('[MeetEventsDataSource] POST $url');

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'spaceName': spaceName}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to subscribe: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50}) async {
    final url = Uri.parse('$baseUrl/api/meet-events/events?limit=$limit');
    debugPrint('[MeetEventsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch events: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final events = body['events'] as List<dynamic>? ?? [];
    return events.cast<Map<String, dynamic>>();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    final url = Uri.parse('$baseUrl/api/meet-events/subscriptions');
    debugPrint('[MeetEventsDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch subscriptions: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final subs = body['subscriptions'] as List<dynamic>? ?? [];
    return subs.cast<Map<String, dynamic>>();
  }

  @override
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId}) {
    // Close any existing connection
    disconnectEventStream();

    _streamController = StreamController<Map<String, dynamic>>.broadcast();

    final sseUrl = lastEventId != null
        ? '$baseUrl/api/meet-events/stream?lastEventId=$lastEventId'
        : '$baseUrl/api/meet-events/stream';

    debugPrint('[MeetEventsDataSource] SSE connecting to $sseUrl');

    _eventSource = html.EventSource(sseUrl);

    _eventSource!.addEventListener('meet-event', (html.Event event) {
      final messageEvent = event as html.MessageEvent;
      try {
        final data = json.decode(messageEvent.data as String)
            as Map<String, dynamic>;
        _streamController?.add(data);
      } catch (e) {
        debugPrint('[MeetEventsDataSource] SSE parse error: $e');
      }
    });

    _eventSource!.onOpen.listen((_) {
      debugPrint('[MeetEventsDataSource] SSE connected');
    });

    _eventSource!.onError.listen((event) {
      debugPrint('[MeetEventsDataSource] SSE error — will auto-reconnect');
      // EventSource handles reconnection automatically
    });

    return _streamController!.stream;
  }

  @override
  void disconnectEventStream() {
    _eventSource?.close();
    _eventSource = null;
    _streamController?.close();
    _streamController = null;
  }
}
