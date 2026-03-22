import 'package:injectable/injectable.dart';
import '../../domain/entities/log_entry_entity.dart';
import '../../domain/repositories/logs_repository.dart';
import '../datasources/logs_data_source.dart';
import '../mappers/log_mappers.dart';

@LazySingleton(as: LogsRepository)
class LogsRepositoryImpl implements LogsRepository {
  final LogsDataSource _dataSource;

  LogsRepositoryImpl(this._dataSource);

  @override
  Future<List<LogEntry>> getLogs({int limit = 50}) async {
    final models = await _dataSource.fetchLogs(limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }
}
