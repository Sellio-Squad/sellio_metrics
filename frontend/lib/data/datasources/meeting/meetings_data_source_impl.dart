// ─── Data Source Impl: Meetings ──────────────────────────────────────────────
//
// WebSocket handling uses dart:io WebSocket for native platforms.
// For web, use web_socket_channel (add to pubspec.yaml if not present).

import 'dart:async';
import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/meeting/meetings_data_source.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.prod])
class MeetingsDataSourceImpl implements MeetingsDataSource {
  final ApiClient _apiClient;

  MeetingsDataSourceImpl(this._apiClient);

  // ─── Active WebSocket connections (one per meetingId) ──────────────────────

  final Map<String, WebSocketChannel> _channels       = {};
  final Map<String, StreamController<MeetingWsEvent>> _controllers = {};

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  @override
  Future<MeetingModel> createMeeting(String title) async {
    try {
      return await _apiClient.post(
        ApiEndpoints.meetings,
        data: {'title': title},
        parser: (data) => MeetingModel.fromJson(data as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        final body = e.data as Map<String, dynamic>? ?? {};
        if (body['requiresAuth'] == true) throw Exception('AUTH_REQUIRED');
      }
      rethrow;
    }
  }

  @override
  Future<List<MeetingModel>> fetchMeetings() async {
    return _apiClient.get<List<MeetingModel>>(
      ApiEndpoints.meetings,
      parser: (data) => (data as List)
          .map((json) => MeetingModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    return _apiClient.get<Map<String, dynamic>>(ApiEndpoints.meetingDetail(id));
  }

  @override
  Future<void> endMeeting(String id) async {
    await _apiClient.post(ApiEndpoints.meetingEnd(id));
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  @override
  Stream<MeetingWsEvent> watchMeeting(String meetingId) {
    // Return existing stream if already connected
    if (_controllers.containsKey(meetingId)) {
      return _controllers[meetingId]!.stream;
    }

    final controller = StreamController<MeetingWsEvent>.broadcast();
    _controllers[meetingId] = controller;

    final wsUrl = ApiEndpoints.meetingWs(meetingId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channels[meetingId] = channel;

    channel.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          final event = MeetingWsEvent.fromJson(json);
          if (!controller.isClosed) controller.add(event);

          // Auto-close stream when meeting ends
          if (event.type == MeetingWsEventType.meetingEnded) {
            unwatchMeeting(meetingId);
          }
        } catch (_) { /* ignore malformed messages */ }
      },
      onError: (error) {
        if (!controller.isClosed) controller.addError(error);
        _cleanup(meetingId);
      },
      onDone: () {
        _cleanup(meetingId);
      },
    );

    return controller.stream;
  }

  @override
  void unwatchMeeting(String meetingId) {
    _channels[meetingId]?.sink.close();
    _cleanup(meetingId);
  }

  void _cleanup(String meetingId) {
    _channels.remove(meetingId);
    _controllers[meetingId]?.close();
    _controllers.remove(meetingId);
  }
}
