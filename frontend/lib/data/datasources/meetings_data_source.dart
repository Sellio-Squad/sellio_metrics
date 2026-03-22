import '../models/attendance_analytics_model.dart';
import '../models/meeting_model.dart';

abstract class MeetingsDataSource {
  Future<MeetingModel> createMeeting(String title);
  Future<List<MeetingModel>> fetchMeetings();
  Future<Map<String, dynamic>> fetchMeetingDetail(String id);
  Future<Map<String, dynamic>> fetchAttendance(String meetingId);
  Future<AttendanceAnalyticsModel> fetchAnalytics();
  Future<RateLimitModel> fetchRateLimitStatus();
  Future<bool> fetchAuthStatus();
  Future<String> fetchAuthUrl();
  Future<void> logout();
  Future<void> endMeeting(String id);
}
