import 'package:injectable/injectable.dart';
import '../meetings_data_source.dart';
import '../../models/attendance_analytics_model.dart';
import '../../models/meeting_model.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.dev])
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
  ];

  @override
  Future<MeetingModel> createMeeting(String title) async {
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
    return MeetingModel.fromJson(newMeeting);
  }

  @override
  Future<List<MeetingModel>> fetchMeetings() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _meetings.map((m) => MeetingModel.fromJson(m)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _meetings.firstWhere((m) => m['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {'meetingId': meetingId, 'participants': []};
  }

  @override
  Future<AttendanceAnalyticsModel> fetchAnalytics() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return AttendanceAnalyticsModel.fromJson({
      'totalMeetings': 12,
      'totalAttendees': 45,
      'averageDurationMinutes': 35,
      'averageScore': 88,
      'mostActiveParticipants': [],
      'attendanceTrends': [],
    });
  }

  @override
  Future<RateLimitModel> fetchRateLimitStatus() async {
    return const RateLimitModel(
      remaining: 58,
      limit: 60,
      resetAt: '',
      isLow: false,
    );
  }

  @override
  Future<bool> fetchAuthStatus() async => true;

  @override
  Future<String> fetchAuthUrl() async => 'https://fake-auth-url.com';

  @override
  Future<void> logout() async {}

  @override
  Future<void> endMeeting(String id) async {}
}
