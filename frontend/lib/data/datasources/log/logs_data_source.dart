import 'package:sellio_metrics/data/models/log/log_model.dart';

abstract class LogsDataSource {
  Future<List<LogModel>> fetchLogs({int limit = 50});
  Future<void> clearLogs();
  Future<Map<String, dynamic>> fetchKvQuota();
}
