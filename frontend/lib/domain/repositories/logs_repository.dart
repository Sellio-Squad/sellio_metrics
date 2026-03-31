import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';

abstract class LogsRepository {
  Future<List<LogEntry>> getLogs({int limit = 50});
  Future<void> clearLogs();
}
