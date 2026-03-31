import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';
import 'package:sellio_metrics/domain/repositories/logs_repository.dart';
import 'package:sellio_metrics/data/datasources/log/logs_data_source.dart';
import 'package:sellio_metrics/data/mappers/log/log_mappers.dart';

@LazySingleton(as: LogsRepository)
class LogsRepositoryImpl implements LogsRepository {
  final LogsDataSource _dataSource;

  LogsRepositoryImpl(this._dataSource);

  @override
  Future<List<LogEntry>> getLogs({int limit = 50}) async {
    final models = await _dataSource.fetchLogs(limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> clearLogs() async {
    await _dataSource.clearLogs();
  }
}
