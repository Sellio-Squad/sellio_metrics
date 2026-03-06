import 'package:flutter/foundation.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/repositories/metrics_repository.dart';

enum DataLoadingStatus { loading, loaded, error }

class PrDataProvider extends ChangeNotifier {
  final MetricsRepository _repository;

  PrDataProvider({required MetricsRepository repository})
    : _repository = repository;

  DataLoadingStatus _status = DataLoadingStatus.loading;
  List<PrEntity> _allPrs = [];
  List<RepoInfo> _currentRepos = [];

  DataLoadingStatus get status => _status;
  List<PrEntity> get allPrs => _allPrs;
  List<RepoInfo> get currentRepos => _currentRepos;

  void setError(String message) {
    _status = DataLoadingStatus.error;
    debugPrint('[PrDataProvider] $message');
    notifyListeners();
  }

  Future<void> ensureDataLoaded(List<RepoInfo> repos) async {
    if (repos.isEmpty) return;

    if (_currentRepos.length == repos.length &&
        _currentRepos.every(
          (r1) => repos.any((r2) => r1.fullName == r2.fullName),
        )) {
      return;
    }

    await loadData(repos: repos);
  }

  Future<void> loadData({List<RepoInfo>? repos}) async {
    final rs = repos ?? _currentRepos;

    if (rs.isEmpty) {
      debugPrint('[PrDataProvider] No repos set. Waiting for selection.');
      return;
    }

    _currentRepos = List.from(rs);
    _status = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregatedPrs = [];
      for (final repo in rs) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        final prs = await _repository.getPullRequests(owner, repoName);
        aggregatedPrs.addAll(prs);
      }
      _allPrs = aggregatedPrs;
      _status = DataLoadingStatus.loaded;
    } catch (e) {
      _status = DataLoadingStatus.error;
      debugPrint('Error loading PR data: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_currentRepos.isEmpty) return;

    _status = DataLoadingStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregatedPrs = [];
      for (final repo in _currentRepos) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        final prs = await _repository.refresh(owner, repoName);
        aggregatedPrs.addAll(prs);
      }
      _allPrs = aggregatedPrs;
      _status = DataLoadingStatus.loaded;
    } catch (e) {
      _status = DataLoadingStatus.error;
      debugPrint('Error refreshing PR data: $e');
    }
    notifyListeners();
  }
}
