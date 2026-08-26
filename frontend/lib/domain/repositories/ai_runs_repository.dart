import 'package:sellio_metrics/data/datasources/ai_pipeline/ai_runs_websocket_data_source.dart';
import 'package:sellio_metrics/domain/entities/ai_run_entity.dart';

abstract class AiRunsUpdate {}

class AiRunsSnapshotUpdate extends AiRunsUpdate {
  final List<AiRunEntity> runs;
  AiRunsSnapshotUpdate(this.runs);
}

class AiRunSingleUpdate extends AiRunsUpdate {
  final AiRunEntity run;
  AiRunSingleUpdate(this.run);
}

class AiRunDeleteUpdate extends AiRunsUpdate {
  final String taskId;
  AiRunDeleteUpdate(this.taskId);
}

class AiRunsClearedUpdate extends AiRunsUpdate {
  AiRunsClearedUpdate();
}

class AiRunLogUpdate extends AiRunsUpdate {
  final String taskId;
  final int issueNumber;
  final String line;
  final DateTime timestamp;
  AiRunLogUpdate({
    required this.taskId,
    required this.issueNumber,
    required this.line,
    required this.timestamp,
  });
}

abstract class AiRunsRepository {
  Stream<AiRunsUpdate> watchAiRuns();
  Stream<WsConnectionStatus> watchConnectionStatus();
  Future<void> deleteRun(String taskId);
  Future<void> clearRuns();
}

