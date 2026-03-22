import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/log/log_model.dart';
import 'logs_data_source.dart';

@Injectable(as: LogsDataSource, env: [Environment.prod])
class LogsDataSourceImpl implements LogsDataSource {
  final ApiClient _apiClient;

  LogsDataSourceImpl(this._apiClient);

  @override
  Future<List<LogModel>> fetchLogs({int limit = 50}) async {
    return await _apiClient.get<List<LogModel>>(
      '/api/logs',
      queryParameters: {'limit': limit},
      parser: (data) {
        if (data is List) {
          return data.map((json) => LogModel.fromJson(json as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
  }
}
