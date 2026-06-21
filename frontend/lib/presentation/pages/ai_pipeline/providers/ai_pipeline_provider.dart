import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/ai_pipeline/ai_runs_websocket_data_source.dart';
import 'package:sellio_metrics/domain/entities/ai_run_entity.dart';
import 'package:sellio_metrics/domain/repositories/ai_runs_repository.dart';

@lazySingleton
class AiPipelineProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AiRunsRepository _repository;

  List<AiRunEntity> _runs = [];
  WsConnectionStatus _connectionStatus = WsConnectionStatus.connecting;
  bool _isLoaded = false; // true once we've received at least one snapshot

  StreamSubscription<AiRunsUpdate>? _runsSubscription;
  StreamSubscription<WsConnectionStatus>? _statusSubscription;

  AiPipelineProvider(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _initStreams();
  }

  List<AiRunEntity> get runs => _runs;
  WsConnectionStatus get connectionStatus => _connectionStatus;
  bool get isLoaded => _isLoaded;

  List<AiRunEntity> get activeRuns => _runs
      .where((r) => r.status == AiRunStatus.inProgress || r.status == AiRunStatus.ciPolling)
      .toList();

  List<AiRunEntity> get historyRuns => _runs
      .where((r) => r.status == AiRunStatus.completed || r.status == AiRunStatus.failed)
      .toList();

  void _initStreams() {
    _runsSubscription?.cancel();
    _statusSubscription?.cancel();

    _statusSubscription = _repository.watchConnectionStatus().listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });

    _runsSubscription = _repository.watchAiRuns().listen((update) {
      if (update is AiRunsSnapshotUpdate) {
        // Only replace if the snapshot has data — prevents blank-out on reconnect
        // with empty KV. If the snapshot is empty and we already have runs loaded,
        // keep the existing runs to avoid flicker.
        if (update.runs.isNotEmpty || !_isLoaded) {
          _runs = update.runs;
        }
        _isLoaded = true;
      } else if (update is AiRunSingleUpdate) {
        final index = _runs.indexWhere((r) => r.taskId == update.run.taskId);
        if (index != -1) {
          _runs[index] = update.run;
        } else {
          _runs.insert(0, update.run);
        }
        _isLoaded = true;
      }
      _runs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    }, onError: (err) {
      _connectionStatus = WsConnectionStatus.disconnected;
      notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op: the data source handles reconnection automatically
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runsSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}
