import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/meeting/attendance_analytics_model.dart';
import '../../models/meeting/meeting_model.dart';
import '../../models/meeting/rate_limit_model.dart';
import 'meetings_data_source.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.prod])
class MeetingsDataSourceImpl implements MeetingsDataSource {
  final ApiClient _apiClient;

  MeetingsDataSourceImpl(this._apiClient);

  @override
  Future<MeetingModel> createMeeting(String title) async {
    try {
      return await _apiClient.post(
        '/api/meetings',
        data: {'title': title},
        parser: (data) => MeetingModel.fromJson(data as Map<String, dynamic>),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        final body = e.data as Map<String, dynamic>? ?? {};
        if (body['requiresAuth'] == true) {
          throw Exception('AUTH_REQUIRED');
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<MeetingModel>> fetchMeetings() async {
    return await _apiClient.get<List<MeetingModel>>(
      '/api/meetings',
      parser: (data) => (data as List)
          .map((json) => MeetingModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    return await _apiClient.get<Map<String, dynamic>>('/api/meetings/$id');
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    return await _apiClient.get<Map<String, dynamic>>('/api/meetings/$meetingId/attendance');
  }

  @override
  Future<AttendanceAnalyticsModel> fetchAnalytics() async {
    return await _apiClient.get<AttendanceAnalyticsModel>(
      '/api/meetings/analytics',
      parser: (data) => AttendanceAnalyticsModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<RateLimitModel> fetchRateLimitStatus() async {
    return await _apiClient.get<RateLimitModel>(
      '/api/meetings/rate-limit',
      parser: (data) => RateLimitModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> endMeeting(String id) async {
    await _apiClient.post('/api/meetings/$id/end');
  }
}
