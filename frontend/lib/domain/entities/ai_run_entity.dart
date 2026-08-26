enum AiRunStatus {
  inProgress,
  completed,
  failed,
  ciPolling,
}

enum AiRunEventStatus {
  running,
  done,
  failed,
}

enum AiRunPhase {
  phase1,
  phase2,
  phase3,
  ciPoll,
  failed,
}

class AiRunEventEntity {
  final AiRunPhase phase;
  final String label;
  final String? detail;
  final DateTime timestamp;
  final AiRunEventStatus status;

  const AiRunEventEntity({
    required this.phase,
    required this.label,
    this.detail,
    required this.timestamp,
    required this.status,
  });

  factory AiRunEventEntity.fromJson(Map<String, dynamic> json) {
    return AiRunEventEntity(
      phase: _parsePhase(json['phase'] as String),
      label: json['label'] as String,
      detail: json['detail'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: _parseEventStatus(json['status'] as String),
    );
  }

  static AiRunPhase _parsePhase(String val) {
    switch (val) {
      case 'phase1': return AiRunPhase.phase1;
      case 'phase2': return AiRunPhase.phase2;
      case 'phase3': return AiRunPhase.phase3;
      case 'ci_poll': return AiRunPhase.ciPoll;
      case 'failed': return AiRunPhase.failed;
      default: return AiRunPhase.failed;
    }
  }

  static AiRunEventStatus _parseEventStatus(String val) {
    switch (val) {
      case 'running': return AiRunEventStatus.running;
      case 'done': return AiRunEventStatus.done;
      case 'failed': return AiRunEventStatus.failed;
      default: return AiRunEventStatus.failed;
    }
  }
}

class AiRunEntity {
  final String taskId;
  final String owner;
  final String repo;
  final int issueNumber;
  final String issueTitle;
  final String issueUrl;
  final AiRunStatus status;
  final int? prNumber;
  final String? prUrl;
  final String? branchName;
  final DateTime startedAt;
  final DateTime updatedAt;
  final List<AiRunEventEntity> events;
  final List<AiRunLogEntity> logs;

  const AiRunEntity({
    required this.taskId,
    required this.owner,
    required this.repo,
    required this.issueNumber,
    required this.issueTitle,
    required this.issueUrl,
    required this.status,
    this.prNumber,
    this.prUrl,
    this.branchName,
    required this.startedAt,
    required this.updatedAt,
    required this.events,
    this.logs = const [],
  });

  factory AiRunEntity.fromJson(Map<String, dynamic> json) {
    final eventList = (json['events'] as List? ?? [])
        .map((e) => AiRunEventEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    final logList = (json['logs'] as List? ?? [])
        .map((l) => AiRunLogEntity.fromJson(l as Map<String, dynamic>))
        .toList();

    return AiRunEntity(
      taskId: json['taskId'] as String,
      owner: json['owner'] as String,
      repo: json['repo'] as String,
      issueNumber: json['issueNumber'] as int,
      issueTitle: json['issueTitle'] as String,
      issueUrl: json['issueUrl'] as String,
      status: _parseRunStatus(json['status'] as String),
      prNumber: json['prNumber'] as int?,
      prUrl: json['prUrl'] as String?,
      branchName: json['branchName'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      events: eventList,
      logs: logList,
    );
  }

  AiRunEntity copyWith({
    String? taskId,
    String? owner,
    String? repo,
    int? issueNumber,
    String? issueTitle,
    String? issueUrl,
    AiRunStatus? status,
    int? prNumber,
    String? prUrl,
    String? branchName,
    DateTime? startedAt,
    DateTime? updatedAt,
    List<AiRunEventEntity>? events,
    List<AiRunLogEntity>? logs,
  }) {
    return AiRunEntity(
      taskId: taskId ?? this.taskId,
      owner: owner ?? this.owner,
      repo: repo ?? this.repo,
      issueNumber: issueNumber ?? this.issueNumber,
      issueTitle: issueTitle ?? this.issueTitle,
      issueUrl: issueUrl ?? this.issueUrl,
      status: status ?? this.status,
      prNumber: prNumber ?? this.prNumber,
      prUrl: prUrl ?? this.prUrl,
      branchName: branchName ?? this.branchName,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      events: events ?? this.events,
      logs: logs ?? this.logs,
    );
  }

  static AiRunStatus _parseRunStatus(String val) {
    switch (val) {
      case 'in_progress': return AiRunStatus.inProgress;
      case 'completed': return AiRunStatus.completed;
      case 'failed': return AiRunStatus.failed;
      case 'ci_polling': return AiRunStatus.ciPolling;
      default: return AiRunStatus.failed;
    }
  }
}

class AiRunLogEntity {
  final String message;
  final DateTime timestamp;

  const AiRunLogEntity({
    required this.message,
    required this.timestamp,
  });

  factory AiRunLogEntity.fromJson(Map<String, dynamic> json) {
    return AiRunLogEntity(
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
