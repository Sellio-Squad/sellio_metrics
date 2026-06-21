import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/ai_pipeline/ai_runs_websocket_data_source.dart';
import 'package:sellio_metrics/domain/entities/ai_run_entity.dart';
import 'package:sellio_metrics/domain/repositories/ai_runs_repository.dart';

@LazySingleton(as: AiRunsRepository)
class AiRunsRepositoryImpl implements AiRunsRepository {
  final AiRunsWebSocketDataSource _dataSource;

  AiRunsRepositoryImpl(this._dataSource);

  @override
  Stream<AiRunsUpdate> watchAiRuns() {
    _dataSource.connect();
    
    return _dataSource.runsStream.transform<AiRunsUpdate>(
      StreamTransformer<Map<String, dynamic>, AiRunsUpdate>.fromHandlers(
        handleData: (json, sink) {
          try {
            final type = json['type'] as String?;
            if (type == 'snapshot') {
              final rawRuns = json['runs'] as List? ?? [];
              final runs = rawRuns
                  .map((e) => AiRunEntity.fromJson(e as Map<String, dynamic>))
                  .toList();
              sink.add(AiRunsSnapshotUpdate(runs));
            } else if (type == 'run_update') {
              final rawRun = json['run'] as Map<String, dynamic>?;
              if (rawRun != null) {
                final run = AiRunEntity.fromJson(rawRun);
                sink.add(AiRunSingleUpdate(run));
              }
            }
          } catch (_) {
            // ignore parsing errors
          }
        },
      ),
    );
  }

  @override
  Stream<bool> watchConnectionStatus() => _dataSource.connectionStatusStream;
}
