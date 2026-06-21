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

abstract class AiRunsRepository {
  Stream<AiRunsUpdate> watchAiRuns();
  Stream<bool> watchConnectionStatus();
}

