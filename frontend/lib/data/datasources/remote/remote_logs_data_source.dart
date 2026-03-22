import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../logs_data_source.dart';
import '../../models/log_model.dart';

@Injectable(as: LogsDataSource, env: [Environment.prod])
class RemoteLogsDataSource implements LogsDataSource {
  final Dio _dio;

  RemoteLogsDataSource(this._dio);

  @override
  Future<List<LogModel>> fetchLogs({int limit = 50}) async {
    try {
      final response = await _dio.get('/api/logs', queryParameters: {'limit': limit});
      
      final data = response.data;
      if (data is List) {
        return data.map((json) => LogModel.fromJson(json as Map<String, dynamic>)).toList();
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
}
