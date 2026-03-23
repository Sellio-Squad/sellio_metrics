import 'package:sellio_metrics/data/models/meeting/attendance_analytics_model.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/data/models/meeting/rate_limit_model.dart';

abstract class MeetingsDataSource {
  Future<MeetingModel> createMeeting(String title);
  Future<List<MeetingModel>> fetchMeetings();
  Future<Map<String, dynamic>> fetchMeetingDetail(String id);
  Future<void> endMeeting(String id);
  Future<Map<String, dynamic>> fetchAttendance(String meetingId);
  Future<AttendanceAnalyticsModel> fetchAnalytics();
  Future<RateLimitModel> fetchRateLimitStatus();
}
