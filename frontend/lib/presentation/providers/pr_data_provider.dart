import 'package:flutter/material.dart';

import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/repo_info.dart';
import '../../domain/repositories/pr_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/logging/app_logger.dart';

enum DataLoadingStatus { loading, loaded, error }

class PrDataProvider extends ChangeNotifier {
  final PrRepository _repository;

  PrDataProvider({required PrRepository repository})
    : _repository = repository;

  DataLoadingStatus _status = DataLoadingStatus.loading;
  // All PRs (unfiltered) loaded once from all available repos
  List<PrEntity> _allPrs = [];
  // Current repos that have been loaded
  List<RepoInfo> _loadedRepos = [];
  // Open PRs specifically fetched with state=open
  List<PrEntity> _openPrs = [];
  DataLoadingStatus _openPrsStatus = DataLoadingStatus.loading;

  DataLoadingStatus get status => _status;
  List<PrEntity> get allPrs => _allPrs;
  List<RepoInfo> get loadedRepos => _loadedRepos;
  List<PrEntity> get openPrs => _openPrs;
  DataLoadingStatus get openPrsStatus => _openPrsStatus;

  void setError(String message) {
    _status = DataLoadingStatus.error;
    sl.get<AppLogger>().error('PrDataProvider', message);
    notifyListeners();
  }

  /// Filter allPrs by a subset of repos (client-side, no API call).
  List<PrEntity> filterByRepos(List<RepoInfo> selectedRepos) {
    if (selectedRepos.isEmpty) return _allPrs;
    final names = selectedRepos.map((r) => r.name.toLowerCase()).toSet();
    return _allPrs.where((pr) {
      final repoName = pr.repoName.split('/').last.toLowerCase();
      return names.contains(repoName);
    }).toList();
  }

  /// Load all PRs from [repos] (typically ALL available repos).
  /// Safe to call multiple times — will skip if same repos are already loaded.
  Future<void> ensureDataLoaded(List<RepoInfo> repos) async {
    if (repos.isEmpty) return;

    // Skip if same set already loaded
    if (_loadedRepos.length == repos.length &&
        _loadedRepos.every(
          (r1) => repos.any((r2) => r1.fullName == r2.fullName),
        )) {
      return;
    }

    await loadData(repos: repos);
  }

  /// Load all-state PRs for analytics/leaderboard (state=all).
  Future<void> loadData({List<RepoInfo>? repos}) async {
    final rs = repos ?? _loadedRepos;
    if (rs.isEmpty) {
      sl.get<AppLogger>().info('PrDataProvider', 'No repos set. Waiting for selection.');
      return;
    }

    _loadedRepos = List.from(rs);
    _status = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregatedPrs = [];
      for (final repo in rs) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        // Fetch all PRs (state=all) for analytics
        final prs = await _repository.fetchPrs(org: owner, repo: repoName, state: 'all');
        aggregatedPrs.addAll(prs);
      }
      _allPrs = aggregatedPrs;
      _status = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _status = DataLoadingStatus.error;
      sl.get<AppLogger>().error('PrDataProvider', 'Error loading PR data: $e', stack);
    }
    notifyListeners();
  }

  /// Load only open PRs (state=open) for the Open PRs page.
  Future<void> loadOpenPrs({List<RepoInfo>? repos}) async {
    final rs = repos ?? _loadedRepos;
    if (rs.isEmpty) return;

    _openPrsStatus = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregated = [];
      for (final repo in rs) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        final prs = await _repository.fetchPrs(org: owner, repo: repoName, state: 'open');
        aggregated.addAll(prs);
      }
      _openPrs = aggregated;
      _openPrsStatus = DataLoadingStatus.loaded;
    } catch (e, stack) {
      _openPrsStatus = DataLoadingStatus.error;
      sl.get<AppLogger>().error('PrDataProvider', 'Error loading open PRs: $e', stack);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadData();
  }
}
