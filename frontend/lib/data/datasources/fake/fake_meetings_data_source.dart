// ─── Fake Data Source: Meetings (dev env) ────────────────────────────────────

import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/meeting/meetings_data_source.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.dev])
class FakeMeetingsDataSource implements MeetingsDataSource {
  final List<Map<String, dynamic>> _meetings = [
    {
      'id':               'meet_1',
      'title':            'Daily Standup',
      'spaceName':        'spaces/abc',
      'meetingUri':       'https://meet.google.com/abc-defg-hij',
      'meetingCode':      'abc-defg-hij',
      'createdAt':        DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      'participantCount': 3,
      'subscribed':       true,
    },
  ];

  @override
  Future<MeetingModel> createMeeting(String title) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final m = {
      'id':               'meet_${DateTime.now().millisecondsSinceEpoch}',
      'title':            title,
      'spaceName':        'spaces/new',
      'meetingUri':       'https://meet.google.com/new-meet-ing',
      'meetingCode':      'new-meet-ing',
      'createdAt':        DateTime.now().toIso8601String(),
      'participantCount': 0,
      'subscribed':       true,
    };
    _meetings.insert(0, m);
    return MeetingModel.fromJson(m);
  }

  @override
  Future<List<MeetingModel>> fetchMeetings() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _meetings.map((m) => MeetingModel.fromJson(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final m = _meetings.firstWhere((m) => m['id'] == id);
    return {
      ...m,
      'participants': [
        {
          'participantKey':       'users/123',
          'displayName':          'Alice',
          'startTime':            DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
          'endTime':              null,
          'totalDurationMinutes': 0,
        },
      ],
    };
  }

  @override
  Future<void> endMeeting(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _meetings.removeWhere((m) => m['id'] == id);
  }

  // ─── WebSocket (fake stream emitting a joined + left after 5s) ─────────────

  final Map<String, StreamController<MeetingWsEvent>> _controllers = {};

  @override
  Stream<MeetingWsEvent> watchMeeting(String meetingId) {
    final controller = StreamController<MeetingWsEvent>.broadcast();
    _controllers[meetingId] = controller;

    // Simulate a participant joining immediately
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!controller.isClosed) {
        controller.add(MeetingWsEvent(
          type:           MeetingWsEventType.participantJoined,
          meetingId:      meetingId,
          participantKey: 'users/fake_1',
          displayName:    'Alice (demo)',
          timestamp:      DateTime.now(),
        ));
      }
    });

    // Simulate a participant leaving after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (!controller.isClosed) {
        controller.add(MeetingWsEvent(
          type:           MeetingWsEventType.participantLeft,
          meetingId:      meetingId,
          participantKey: 'users/fake_1',
          displayName:    'Alice (demo)',
          timestamp:      DateTime.now(),
        ));
      }
    });

    return controller.stream;
  }

  @override
  void unwatchMeeting(String meetingId) {
    _controllers[meetingId]?.close();
    _controllers.remove(meetingId);
  }
}
