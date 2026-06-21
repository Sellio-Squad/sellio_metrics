import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/ai_run_entity.dart';
import 'package:sellio_metrics/domain/repositories/ai_runs_repository.dart';

enum ConnectionStateStatus {
  connecting,
  connected,
  disconnected,
}

@lazySingleton
class AiPipelineProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AiRunsRepository _repository;
  
  List<AiRunEntity> _runs = [];
  ConnectionStateStatus _connectionStatus = ConnectionStateStatus.connecting;
  
  StreamSubscription<AiRunsUpdate>? _runsSubscription;
  StreamSubscription<bool>? _statusSubscription;

  AiPipelineProvider(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _initStreams();
  }

  List<AiRunEntity> get runs => _runs;
  ConnectionStateStatus get connectionStatus => _connectionStatus;

  List<AiRunEntity> get activeRuns => _runs
      .where((r) => r.status == AiRunStatus.inProgress || r.status == AiRunStatus.ciPolling)
      .toList();

  List<AiRunEntity> get historyRuns => _runs
      .where((r) => r.status == AiRunStatus.completed || r.status == AiRunStatus.failed)
      .toList();

  void _initStreams() {
    _runsSubscription?.cancel();
    _statusSubscription?.cancel();

    _statusSubscription = _repository.watchConnectionStatus().listen((isConnected) {
      _connectionStatus = isConnected ? ConnectionStateStatus.connected : ConnectionStateStatus.connecting;
      notifyListeners();
    });

    _runsSubscription = _repository.watchAiRuns().listen((update) {
      if (update is AiRunsSnapshotUpdate) {
        _runs = update.runs;
      } else if (update is AiRunSingleUpdate) {
        final index = _runs.indexWhere((r) => r.taskId == update.run.taskId);
        if (index != -1) {
          _runs[index] = update.run;
        } else {
          _runs.insert(0, update.run);
        }
      }
      _runs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    }, onError: (err) {
      _connectionStatus = ConnectionStateStatus.disconnected;
      notifyListeners();
    });
  }

  void _reconnect() {
    _initStreams();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runsSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
