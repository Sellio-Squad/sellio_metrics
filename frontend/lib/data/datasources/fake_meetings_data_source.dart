/// Fake Meetings Data Source
///
/// In-memory implementation of [MeetingsDataSource] for UI testing
/// without a backend.
library;

import '../datasources/meetings_data_source.dart';

class FakeMeetingsDataSource implements MeetingsDataSource {
  final List<Map<String, dynamic>> _meetings = [
    {
      'id': 'meet_1',
      'title': 'Daily Standup',
      'spaceName': 'spaces/abc',
      'meetingUri': 'https://meet.google.com/abc-defg-hij',
      'meetingCode': 'abc-defg-hij',
      'createdAt': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String(),
      'participantCount': 5,
    },
    {
      'id': 'meet_2',
      'title': 'Sprint Planning',
      'spaceName': 'spaces/def',
      'meetingUri': 'https://meet.google.com/def-ghij-klm',
      'meetingCode': 'def-ghij-klm',
      'createdAt': DateTime.now().toIso8601String(),
      'participantCount': 0,
    },
  ];

  @override
  Future<Map<String, dynamic>> createMeeting(String title) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final newMeeting = {
      'id': 'meet_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'spaceName': 'spaces/new',
      'meetingUri': 'https://meet.google.com/new-meet-ing',
      'meetingCode': 'new-meet-ing',
      'createdAt': DateTime.now().toIso8601String(),
      'participantCount': 0,
    };
    _meetings.insert(0, newMeeting);
    return newMeeting;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMeetings() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.from(_meetings);
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final meeting = _meetings.firstWhere(
      (m) => m['id'] == id,
      orElse: () => throw Exception('Meeting not found'),
    );

    return {
      ...meeting,
      'participants': [
        {
          'displayName': 'Alice Smith',
          'email': 'alice@example.com',
          'joinTime': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
          'leaveTime': null,
          'durationMinutes': 45,
          'attendanceScore': 100,
        },
        {
          'displayName': 'Bob Jones',
          'email': 'bob@example.com',
          'joinTime': DateTime.now().subtract(const Duration(minutes: 50)).toIso8601String(),
          'leaveTime': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
          'durationMinutes': 40,
          'attendanceScore': 85,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'meetingId': meetingId,
      'meetingTitle': 'Daily Standup',
      'meetingDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'totalDurationMinutes': 60,
      'participants': [
        {
          'displayName': 'Alice Smith',
          'email': 'alice@example.com',
          'joinTime': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'leaveTime': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'durationMinutes': 45,
          'attendanceScore': 95,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchAnalytics() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'totalMeetings': 12,
      'totalAttendees': 45,
      'averageDurationMinutes': 35,
      'averageScore': 88,
      'mostActiveParticipants': [
        {
          'displayName': 'Alice Smith',
          'email': 'alice@example.com',
          'meetingsAttended': 10,
          'totalMinutes': 350,
          'averageScore': 95,
        },
        {
          'displayName': 'Bob Jones',
          'email': 'bob@example.com',
          'meetingsAttended': 8,
          'totalMinutes': 280,
          'averageScore': 82,
        },
      ],
      'attendanceTrends': [
        {'date': '2023-10-01', 'attendeeCount': 5, 'averageDuration': 30},
        {'date': '2023-10-02', 'attendeeCount': 8, 'averageDuration': 45},
        {'date': '2023-10-03', 'attendeeCount': 6, 'averageDuration': 35},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchRateLimitStatus() async {
    return {
      'remaining': 58,
      'limit': 60,
      'resetAt': DateTime.now().add(const Duration(seconds: 45)).toIso8601String(),
      'isLow': false,
    };
  }
}
