import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../data/datasources/fake/fake_logs.dart'; // Retaining the types

@injectable
class LogsDataSource {
  final Dio _dio;

  LogsDataSource(this._dio);

  Future<List<LogEntry>> fetchLogs({int limit = 50}) async {
    try {
      final response = await _dio.get('/api/logs', queryParameters: {'limit': limit});
      
      final data = response.data;
      if (data is List) {
        return data.map((json) => _parseLogEntry(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['error'] ?? 'Failed to fetch logs',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  LogEntry _parseLogEntry(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
      severity: _parseSeverity(json['severity']),
      category: _parseCategory(json['category']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  LogSeverity _parseSeverity(String? severity) {
    switch (severity) {
      case 'info':
        return LogSeverity.info;
      case 'warning':
        return LogSeverity.warning;
      case 'error':
        return LogSeverity.error;
      case 'success':
        return LogSeverity.success;
      default:
        return LogSeverity.info;
    }
  }

  LogCategory _parseCategory(String? category) {
    switch (category) {
      case 'github':
        return LogCategory.github;
      case 'googleMeet':
        return LogCategory.googleMeet;
      case 'system':
        return LogCategory.system;
      default:
        return LogCategory.system;
    }
  }
}
