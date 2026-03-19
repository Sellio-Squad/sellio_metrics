library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../core/logging/app_logger.dart';


abstract class MeetingsDataSource {
  Future<Map<String, dynamic>> createMeeting(String title);

  Future<List<Map<String, dynamic>>> fetchMeetings();

  Future<Map<String, dynamic>> fetchMeetingDetail(String id);

  Future<Map<String, dynamic>> fetchAttendance(String meetingId);

  Future<Map<String, dynamic>> fetchAnalytics();

  Future<Map<String, dynamic>> fetchRateLimitStatus();

  Future<bool> fetchAuthStatus();

  Future<String?> fetchAuthUrl();

  Future<void> logout();

  Future<void> endMeeting(String id);
}

class AuthRequiredException implements Exception {
  final String authUrl;
  final String message;

  AuthRequiredException(this.authUrl, this.message);

  @override
  String toString() => message;
}

@Injectable(as: MeetingsDataSource, env: [Environment.prod])
class RemoteMeetingsDataSource implements MeetingsDataSource {
  final Dio _dio;

  RemoteMeetingsDataSource(this._dio);

  @override
  Future<Map<String, dynamic>> createMeeting(String title) async {
    final url = '/api/meetings';
    appLogger.network('MeetingsDataSource', 'POST', Uri.parse(_dio.options.baseUrl + url));

    try {
      final response = await _dio.post(
        url,
        data: {'title': title},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final body = e.response?.data as Map<String, dynamic>? ?? {};
        if (body['authUrl'] != null) {
          throw AuthRequiredException(
            body['authUrl'] as String,
            body['message'] as String? ?? 'Authentication required',
          );
        }
      }
      throw Exception('Failed to create meeting: ${e.response?.statusCode} ${e.response?.data}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMeetings() async {
    final url = '/api/meetings';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch meetings: ${response.statusCode} ${response.data}',
      );
    }

    final List<dynamic> list = response.data as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
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
  Future<Map<String, dynamic>> fetchAnalytics() async {
    final url = '/api/meetings/analytics';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch analytics: ${response.statusCode} ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchRateLimitStatus() async {
    final url = '/api/meetings/rate-limit';
    appLogger.network('MeetingsDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch rate limit: ${response.statusCode} ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  @override
  Future<bool> fetchAuthStatus() async {
    try {
      final url = '/api/meetings/auth-status';
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        return body['isReady'] == true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<String?> fetchAuthUrl() async {
    try {
      final url = '/api/meetings/auth-url';
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        return body['authUrl'] as String?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> logout() async {
    final url = '/api/meetings/auth-logout';
    appLogger.network('MeetingsDataSource', 'POST', Uri.parse(_dio.options.baseUrl + url));
    final response = await _dio.post(url);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to logout: ${response.statusCode} ${response.data}',
      );
    }
  }

  @override
  Future<void> endMeeting(String id) async {
    final url = '/api/meetings/$id/end';
    appLogger.network('MeetingsDataSource', 'POST', Uri.parse(_dio.options.baseUrl + url));
    final response = await _dio.post(url);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to end meeting: ${response.statusCode} ${response.data}',
      );
    }
  }
}
