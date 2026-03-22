import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/logging/app_logger.dart';
import '../meetings_data_source.dart';
import '../../models/attendance_analytics_model.dart';
import '../../models/meeting_model.dart';

@Injectable(as: MeetingsDataSource, env: [Environment.prod])
class RemoteMeetingsDataSource implements MeetingsDataSource {
  final Dio _dio;

  RemoteMeetingsDataSource(this._dio);

  @override
  Future<MeetingModel> createMeeting(String title) async {
    final url = '/api/meetings';
    appLogger.network('MeetingsDataSource', 'POST', Uri.parse(_dio.options.baseUrl + url));

    try {
      final response = await _dio.post(
        url,
        data: {'title': title},
      );

      return MeetingModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final body = e.response?.data as Map<String, dynamic>? ?? {};
        if (body['requiresAuth'] == true) {
          throw Exception('AUTH_REQUIRED');
        }
      }
      rethrow;
    }
  }

  @override
  Future<List<MeetingModel>> fetchMeetings() async {
    final url = '/api/meetings';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch meetings: ${response.statusCode} ${response.data}',
      );
    }

    final List<dynamic> list = response.data as List<dynamic>;
    return list.map((json) => MeetingModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, dynamic>> fetchMeetingDetail(String id) async {
    final url = '/api/meetings/$id';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch meeting detail: ${response.statusCode} ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchAttendance(String meetingId) async {
    final url = '/api/meetings/$meetingId/attendance';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch attendance: ${response.statusCode} ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  @override
  Future<AttendanceAnalyticsModel> fetchAnalytics() async {
    final url = '/api/meetings/analytics';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch analytics: ${response.statusCode} ${response.data}',
      );
    }

    return AttendanceAnalyticsModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<RateLimitModel> fetchRateLimitStatus() async {
    final url = '/api/meetings/rate-limit';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rate limit: ${response.statusCode} ${response.data}',
      );
    }

    return RateLimitModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<bool> fetchAuthStatus() async {
    final url = '/api/meetings/auth/status';
    final response = await _dio.get(url);
    return (response.data as Map<String, dynamic>)['authenticated'] as bool? ?? false;
  }

  @override
  Future<String> fetchAuthUrl() async {
    final url = '/api/meetings/auth/url';
    final response = await _dio.get(url);
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  @override
  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
  }

  @override
  Future<void> endMeeting(String id) async {
    await _dio.post('/api/meetings/$id/end');
  }
}
