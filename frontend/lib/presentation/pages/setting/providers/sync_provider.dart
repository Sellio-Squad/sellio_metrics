/// Sync Module — SyncProvider
///
/// Manages the state for syncing all GitHub repositories into D1.
/// Calls POST /api/sync/github sequentially for each repo.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/repo_info.dart';
import '../../../../domain/repositories/repos_repository.dart';

enum SyncStatus { idle, running, done, error }

class RepoSyncResult {
  final RepoInfo repo;
  final bool success;
  final String? error;
  final int? prsUpserted;
  final int? commentsInserted;

  const RepoSyncResult({
    required this.repo,
    required this.success,
    this.error,
    this.prsUpserted,
    this.commentsInserted,
  });
}

@injectable
class SyncProvider extends ChangeNotifier {
  final ReposRepository _reposRepository;
  final Dio _dio;

  SyncStatus _status = SyncStatus.idle;
  List<RepoInfo> _repos = [];
  int _currentIndex = -1;
  final List<RepoSyncResult> _results = [];
  String? _globalError;

  SyncProvider(this._reposRepository, this._dio);

  SyncStatus get status => _status;
  List<RepoInfo> get repos => _repos;
  int get currentIndex => _currentIndex;
  List<RepoSyncResult> get results => _results;
  String? get globalError => _globalError;
  bool get isRunning => _status == SyncStatus.running;

  /// Progress value 0.0 → 1.0
  double get progress {
    if (_repos.isEmpty) return 0.0;
    if (_status == SyncStatus.done) return 1.0;
    if (_currentIndex < 0) return 0.0;
    return _currentIndex / _repos.length;
  }

  /// Label shown on the progress bar
  String get progressLabel {
    switch (_status) {
      case SyncStatus.idle:
        return 'Ready to sync';
      case SyncStatus.running:
        if (_currentIndex >= 0 && _currentIndex < _repos.length) {
          return 'Syncing ${_repos[_currentIndex].name}...';
        }
        return 'Starting sync...';
      case SyncStatus.done:
        final failed = _results.where((r) => !r.success).length;
        return failed == 0
            ? 'All ${_repos.length} repos synced successfully'
            : '${_repos.length - failed} synced, $failed failed';
      case SyncStatus.error:
        return 'Sync failed: ${_globalError ?? "Unknown error"}';
    }
  }

  Future<void> startSync() async {
    if (_status == SyncStatus.running) return;

    _status = SyncStatus.running;
    _results.clear();
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      // Load repos if not already loaded
      if (_repos.isEmpty) {
        _repos = await _reposRepository.getRepositories();
        notifyListeners();
      }

      if (_repos.isEmpty) {
        _globalError = 'No repositories found in the organization.';
        _status = SyncStatus.error;
        notifyListeners();
        return;
      }

      for (var i = 0; i < _repos.length; i++) {
        _currentIndex = i;
        notifyListeners();

        final repo = _repos[i];
        try {
          final parts = repo.fullName.split('/');
          final owner = parts.length == 2 ? parts[0] : null;
          final repoName = parts.length == 2 ? parts[1] : repo.name;

          final response = await _dio.post(
            '/api/sync/github',
            data: {
              'repo': repoName,
              if (owner != null) 'owner': owner,
            },
          );

          final body = response.data as Map<String, dynamic>;
          _results.add(RepoSyncResult(
            repo: repo,
            success: true,
            prsUpserted: body['prsUpserted'] as int?,
            commentsInserted: body['commentsInserted'] as int?,
          ));
        } catch (e) {
          appLogger.error('SyncProvider', 'Failed to sync ${repo.name}', null);
          _results.add(RepoSyncResult(
            repo: repo,
            success: false,
            error: e.toString(),
          ));
        }

        notifyListeners();
      }

      _currentIndex = _repos.length;
      _status = SyncStatus.done;
    } catch (e, stack) {
      _globalError = e.toString();
      _status = SyncStatus.error;
      appLogger.error('SyncProvider', 'Sync failed', stack);
    }

    notifyListeners();
  }

  void reset() {
    _status = SyncStatus.idle;
    _currentIndex = -1;
    _results.clear();
    _globalError = null;
    notifyListeners();
  }
}
