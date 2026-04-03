import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/core/logging/app_logger.dart';
import 'package:sellio_metrics/data/datasources/log/logs_data_source.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/repositories/repos_repository.dart';

enum SyncStatus { idle, running, done, error, resetting }

class RepoSyncResult {
  final RepoInfo repo;
  final bool success;
  final String? error;
  final int? prsUpserted;
  final int? commentsInserted;
  final int? commitsInserted;
  final int? linesAdded;
  final int? linesDeleted;
  final List<Map<String, dynamic>> fetchFailures;

  const RepoSyncResult({
    required this.repo,
    required this.success,
    this.error,
    this.prsUpserted,
    this.commentsInserted,
    this.commitsInserted,
    this.linesAdded,
    this.linesDeleted,
    this.fetchFailures = const [],
  });

  bool get hasWarnings => fetchFailures.isNotEmpty;
}

@injectable
class SyncProvider extends ChangeNotifier {
  final ReposRepository _reposRepository;
  final LogsDataSource  _logsDataSource;

  SyncStatus _status = SyncStatus.idle;
  List<RepoInfo> _repos = [];
  Set<String> _selectedRepoNames = {};
  int _currentIndex = -1;
  final List<RepoSyncResult> _results = [];
  String? _globalError;

  SyncProvider(this._reposRepository, this._logsDataSource);

  SyncStatus get status => _status;
  List<RepoInfo> get repos => _repos;
  Set<String> get selectedRepoNames => _selectedRepoNames;
  int get currentIndex => _currentIndex;
  List<RepoSyncResult> get results => _results;
  String? get globalError => _globalError;
  bool get isRunning => _status == SyncStatus.running;

  /// Fetch KV write quota for today — used by _KvQuotaBar on the sync page.
  Future<Map<String, dynamic>> fetchKvQuota() => _logsDataSource.fetchKvQuota();

  List<RepoInfo> get availableRepos => _repos;

  List<RepoInfo> get selectedRepos => _repos
      .where((r) => _selectedRepoNames.contains(r.fullName))
      .toList();

  double get progress {
    final total = selectedRepos.length;
    if (total == 0) return 0.0;
    if (_status == SyncStatus.done) return 1.0;
    if (_currentIndex < 0) return 0.0;
    return _currentIndex / total;
  }

  String get progressLabel {
    final selected = selectedRepos;
    switch (_status) {
      case SyncStatus.idle:
        return 'Ready to sync ${selected.length} repos';
      case SyncStatus.running:
        if (_currentIndex >= 0 && _currentIndex < selected.length) {
          return 'Syncing ${selected[_currentIndex].name}…';
        }
        return 'Starting sync…';
      case SyncStatus.done:
        final failed = _results.where((r) => !r.success).length;
        final warned = _results.where((r) => r.success && r.hasWarnings).length;
        if (failed == 0 && warned == 0) {
          return 'All ${selected.length} repos synced successfully';
        }
        final parts = <String>[];
        if (failed > 0) parts.add('$failed failed');
        if (warned > 0) parts.add('$warned with warnings');
        return '${selected.length - failed} synced · ${parts.join(', ')}';
      case SyncStatus.error:
        return 'Sync failed: ${_globalError ?? "Unknown error"}';
      case SyncStatus.resetting:
        return 'Resetting database and caches…';
    }
  }

  Future<void> loadRepos() async {
    try {
      _repos = await _reposRepository.getGithubRepositories();
      if (_selectedRepoNames.isEmpty) {
        _selectedRepoNames = _repos.map((r) => r.fullName).toSet();
      }
      notifyListeners();
    } catch (e, stack) {
      _globalError = 'Failed to load repositories. Please check logs or clear cache.';
      _status = SyncStatus.error;
      notifyListeners();
      appLogger.error('SyncProvider', 'Failed to load repos', stack);
    }
  }

  void toggleRepoSelection(RepoInfo repo) {
    if (_selectedRepoNames.contains(repo.fullName)) {
      _selectedRepoNames = {..._selectedRepoNames}..remove(repo.fullName);
    } else {
      _selectedRepoNames = {..._selectedRepoNames, repo.fullName};
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedRepoNames = _repos.map((r) => r.fullName).toSet();
    notifyListeners();
  }

  void deselectAll() {
    _selectedRepoNames = {};
    notifyListeners();
  }

  Future<void> startSync({bool force = false}) async {
    if (_status == SyncStatus.running) return;

    _status = SyncStatus.running;
    _results.clear();
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      if (_repos.isEmpty) {
        await loadRepos();
      }

      final toSync = selectedRepos;
      if (toSync.isEmpty) {
        _globalError = 'No repositories selected. Please select at least one.';
        _status = SyncStatus.error;
        notifyListeners();
        return;
      }

      // Enqueue all repos at once — backend returns 202 + list of jobIds
      final enqueueResult = await _reposRepository.enqueueSyncJobs(
        toSync.map((r) => r.fullName).toList(),
        force: force,
      );

      final jobs = (enqueueResult['jobs'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Now poll each job until it finishes
      for (var i = 0; i < jobs.length; i++) {
        _currentIndex = i;
        notifyListeners();

        final jobId = jobs[i]['jobId'] as String;
        final repo  = toSync[i];
        await _pollJobUntilDone(jobId, repo);
        notifyListeners();
      }

      _currentIndex = toSync.length;
      _status = SyncStatus.done;
    } catch (e, stack) {
      _globalError = e.toString();
      _status = SyncStatus.error;
      appLogger.error('SyncProvider', 'Sync failed', stack);
    }

    notifyListeners();
  }

  /// Poll GET /api/sync/status/:jobId every 3 seconds until status is done/error.
  Future<void> _pollJobUntilDone(String jobId, RepoInfo repo) async {
    const maxWait = Duration(minutes: 10);
    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));

      try {
        final status = await _reposRepository.getSyncJobStatus(jobId);
        final jobStatus = status['status'] as String? ?? 'queued';

        if (jobStatus == 'done') {
          final result = status['result'] as Map<String, dynamic>? ?? {};
          _results.add(RepoSyncResult(
            repo: repo,
            success: true,
            prsUpserted:      result['prsUpserted'] as int?,
            commentsInserted: result['commentsInserted'] as int?,
            commitsInserted:  result['commitsInserted'] as int?,
            linesAdded:       result['linesAdded'] as int?,
            linesDeleted:     result['linesDeleted'] as int?,
          ));
          return;
        }

        if (jobStatus == 'error') {
          _results.add(RepoSyncResult(
            repo: repo,
            success: false,
            error: status['error'] as String? ?? 'Unknown error',
          ));
          return;
        }

        // queued or running — keep polling
      } catch (e) {
        appLogger.error('SyncProvider', 'Failed to poll job $jobId', null);
        // keep trying until deadline
      }
    }

    // Timed out polling
    _results.add(RepoSyncResult(
      repo: repo,
      success: false,
      error: 'Sync job timed out after 10 minutes',
    ));
  }

  Future<void> retryFailed() async {
    if (_status == SyncStatus.running) return;

    final reposToRetry = <RepoInfo, List<int>>{};
    
    for (var r in _results) {
      if (!r.success) {
        reposToRetry[r.repo] = [];
      } else if (r.fetchFailures.isNotEmpty) {
        reposToRetry[r.repo] = r.fetchFailures.map((e) => e['prNumber'] as int).toList();
      }
    }

    if (reposToRetry.isEmpty) return;

    _results.removeWhere((r) => !r.success || r.fetchFailures.isNotEmpty);
    _status = SyncStatus.running;
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      final entries = reposToRetry.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        _currentIndex = i;
        notifyListeners();
        await _syncRepo(entries[i].key, prNumbers: entries[i].value);
        notifyListeners();
      }
      _currentIndex = entries.length;
      _status = SyncStatus.done;
    } catch (e, stack) {
      _globalError = e.toString();
      _status = SyncStatus.error;
      appLogger.error('SyncProvider', 'Retry sync failed', stack);
    }

    notifyListeners();
  }

  Future<void> _syncRepo(RepoInfo repo, {List<int>? prNumbers, bool force = false}) async {
    try {
      final body = await _reposRepository.syncGithub(
        repo.fullName,
        prNumbers: prNumbers,
        force: force,
      );

      final fetchFailures = ((body['fetchFailures'] as List?) ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      _results.add(RepoSyncResult(
        repo: repo,
        success: true,
        prsUpserted:      body['prsUpserted'] as int?,
        commentsInserted: body['commentsInserted'] as int?,
        commitsInserted:  body['commitsInserted'] as int?,
        linesAdded:       body['linesAdded'] as int?,
        linesDeleted:     body['linesDeleted'] as int?,
        fetchFailures:    fetchFailures,
      ));
    } catch (e) {
      appLogger.error('SyncProvider', 'Failed to sync ${repo.name}', null);
      _results.add(RepoSyncResult(
        repo: repo,
        success: false,
        error: e.toString(),
      ));
    }
  }

  void reset() {
    _status = SyncStatus.idle;
    _currentIndex = -1;
    _results.clear();
    _globalError = null;
    notifyListeners();
  }

  Future<void> resetDatabase() async {
    if (_status == SyncStatus.running || _status == SyncStatus.resetting) return;

    _status = SyncStatus.resetting;
    _results.clear();
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      await _reposRepository.syncGithubReset();
      appLogger.info('SyncProvider', 'Database reset successful');
    } catch (e) {
      appLogger.error('SyncProvider', 'Database reset failed', null);
      _globalError = 'Reset failed: ${e.toString()}';
      _status = SyncStatus.error;
      notifyListeners();
      return;
    }

    _status = SyncStatus.idle;
    _repos = [];
    _selectedRepoNames = {};
    notifyListeners();
    // Automatically reload repos after reset
    await loadRepos();
  }

  Future<void> invalidateCache() async {
    if (_status == SyncStatus.running || _status == SyncStatus.resetting) return;

    _status = SyncStatus.resetting;
    _results.clear();
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      await _reposRepository.syncGithubCache();
      appLogger.info('SyncProvider', 'Cache invalidated successfully');
    } catch (e) {
      appLogger.error('SyncProvider', 'Cache invalidation failed', null);
      _globalError = 'Invalidate failed: ${e.toString()}';
      _status = SyncStatus.error;
      notifyListeners();
      return;
    }

    _status = SyncStatus.idle;
    _repos = [];
    _selectedRepoNames = {};
    notifyListeners();
    // Automatically reload repos after cache is cleared
    await loadRepos();
  }
}
