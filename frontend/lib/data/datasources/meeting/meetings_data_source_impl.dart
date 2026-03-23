import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/models/meeting/attendance_analytics_model.dart';
import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/data/models/meeting/rate_limit_model.dart';
import 'package:sellio_metrics/data/datasources/meeting/meetings_data_source.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.prod])
class MeetingsDataSourceImpl implements MeetingsDataSource {
  final ApiClient _apiClient;

  MeetingsDataSourceImpl(this._apiClient);

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
      ApiEndpoints.meetings,
      parser: (data) => (data as List)
          .map((json) => MeetingModel.fromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    return await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.meetingDetail(id));
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    return await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.meetingAttendance(meetingId));
  }

  @override
  Future<AttendanceAnalyticsModel> fetchAnalytics() async {
    return await _apiClient.get<AttendanceAnalyticsModel>(
      ApiEndpoints.meetingAnalytics,
      parser: (data) => AttendanceAnalyticsModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<RateLimitModel> fetchRateLimitStatus() async {
    return await _apiClient.get<RateLimitModel>(
      ApiEndpoints.meetingRateLimit,
      parser: (data) => RateLimitModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<void> endMeeting(String id) async {
    await _apiClient.post(ApiEndpoints.meetingEnd(id));
  }
}
