/// Sync Module — SyncProvider
///
/// Manages the state for syncing selected GitHub repositories into D1.
/// Calls POST /api/sync/github with { repos: [...] } for selected repos.
/// Tracks per-repo results including diff_warning counts.
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
  final int? linesAdded;
  final int? linesDeleted;
  // PRs that still had 0 additions+deletions after all retries (PR numbers)
  final List<int> zeroDiffPrNumbers;
  // PR numbers (#N) that threw an error during getPull (fell back to list-API)
  final List<String> fetchFailures;

  const RepoSyncResult({
    required this.repo,
    required this.success,
    this.error,
    this.prsUpserted,
    this.commentsInserted,
    this.linesAdded,
    this.linesDeleted,
    this.zeroDiffPrNumbers = const [],
    this.fetchFailures = const [],
  });

  /// True if any PRs may have incorrect zero-diff data.
  bool get hasWarnings =>
      zeroDiffPrNumbers.isNotEmpty || fetchFailures.isNotEmpty;
}

@injectable
class SyncProvider extends ChangeNotifier {
  final ReposRepository _reposRepository;
  final Dio _dio;

  SyncStatus _status = SyncStatus.idle;
  List<RepoInfo> _repos = [];
  Set<String> _selectedRepoNames = {};
  int _currentIndex = -1;
  final List<RepoSyncResult> _results = [];
  String? _globalError;

  SyncProvider(this._reposRepository, this._dio);

  SyncStatus get status => _status;
  List<RepoInfo> get repos => _repos;
  Set<String> get selectedRepoNames => _selectedRepoNames;
  int get currentIndex => _currentIndex;
  List<RepoSyncResult> get results => _results;
  String? get globalError => _globalError;
  bool get isRunning => _status == SyncStatus.running;

  /// All repos from which the user can select to sync.
  List<RepoInfo> get availableRepos => _repos;

  /// Currently selected repos (to be synced).
  List<RepoInfo> get selectedRepos => _repos
      .where((r) => _selectedRepoNames.contains(r.fullName))
      .toList();

  /// Progress value 0.0 → 1.0
  double get progress {
    final total = selectedRepos.length;
    if (total == 0) return 0.0;
    if (_status == SyncStatus.done) return 1.0;
    if (_currentIndex < 0) return 0.0;
    return _currentIndex / total;
  }

  /// Label shown on the progress bar
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
    }
  }

  // ─── Repo Selection ──────────────────────────────────────────

  Future<void> loadRepos() async {
    try {
      _repos = await _reposRepository.getRepositories();
      // Default: all repos selected
      if (_selectedRepoNames.isEmpty) {
        _selectedRepoNames = _repos.map((r) => r.fullName).toSet();
      }
      notifyListeners();
    } catch (e, stack) {
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

  // ─── Sync ────────────────────────────────────────────────────

  Future<void> startSync() async {
    if (_status == SyncStatus.running) return;

    _status = SyncStatus.running;
    _results.clear();
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      // Load repos if not yet loaded
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

      for (var i = 0; i < toSync.length; i++) {
        _currentIndex = i;
        notifyListeners();

        final repo = toSync[i];
        await _syncRepo(repo);
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

  /// Retry only the repos that failed in the last sync run.
  Future<void> retryFailed() async {
    if (_status == SyncStatus.running) return;

    final failedRepos = _results
        .where((r) => !r.success)
        .map((r) => r.repo)
        .toList();

    if (failedRepos.isEmpty) return;

    // Remove failed results so we can re-add them
    _results.removeWhere((r) => !r.success);
    _status = SyncStatus.running;
    _currentIndex = -1;
    _globalError = null;
    notifyListeners();

    try {
      for (var i = 0; i < failedRepos.length; i++) {
        _currentIndex = i;
        notifyListeners();
        await _syncRepo(failedRepos[i]);
        notifyListeners();
      }
      _currentIndex = failedRepos.length;
      _status = SyncStatus.done;
    } catch (e, stack) {
      _globalError = e.toString();
      _status = SyncStatus.error;
      appLogger.error('SyncProvider', 'Retry sync failed', stack);
    }

    notifyListeners();
  }

  Future<void> _syncRepo(RepoInfo repo) async {
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
      final zeroDiffNumbers = (body['zeroDiffPrNumbers'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [];
      final fetchFailures = (body['fetchFailures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      _results.add(RepoSyncResult(
        repo: repo,
        success: true,
        prsUpserted: body['prsUpserted'] as int?,
        commentsInserted: body['commentsInserted'] as int?,
        linesAdded: body['linesAdded'] as int?,
        linesDeleted: body['linesDeleted'] as int?,
        zeroDiffPrNumbers: zeroDiffNumbers,
        fetchFailures: fetchFailures,
      ));
    } catch (e) {
      appLogger.error('SyncProvider', 'Failed to sync ${repo.name}', null);
      String errorMessage = e.toString();
      // Extract cleaner message from DioException
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['error'] != null) {
          errorMessage = data['error'].toString();
        }
      }
      _results.add(RepoSyncResult(
        repo: repo,
        success: false,
        error: errorMessage,
      ));
    }
  }

  // ─── Reset ───────────────────────────────────────────────────

  void reset() {
    _status = SyncStatus.idle;
    _currentIndex = -1;
    _results.clear();
    _globalError = null;
    notifyListeners();
  }
}
