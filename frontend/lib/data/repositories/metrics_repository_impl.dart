/// Sellio Metrics — Repository Implementation
///
/// Concrete repository that reads from a [MetricsDataSource]
/// and maps data models to domain entities.
library;

import '../datasources/local_data_source.dart';
import '../mappers/pr_mappers.dart';

import '../../domain/entities/pr_entity.dart';
import '../../domain/repositories/metrics_repository.dart';

class MetricsRepositoryImpl implements MetricsRepository {
  final MetricsDataSource _dataSource;

  /// Cached entities keyed by "owner/repo" to avoid refetching.
  final Map<String, List<PrEntity>> _cache = {};

  MetricsRepositoryImpl({required MetricsDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<PrEntity>> getPullRequests(String owner, String repo) async {
    final key = '$owner/$repo';
    if (_cache.containsKey(key)) return _cache[key]!;
    return _fetchAndMap(owner, repo);
  }

  @override
  Future<List<PrEntity>> refresh(String owner, String repo) async {
    final key = '$owner/$repo';
    _cache.remove(key);
    return _fetchAndMap(owner, repo);
  }

  @override
  Future<List<RepoInfo>> getRepositories() async {
    final repos = await _dataSource.fetchRepositories();
    return repos
        .map((r) => RepoInfo(
              name: r.name,
              fullName: r.fullName,
              description: r.description,
            ))
        .toList();
  }

  Future<List<PrEntity>> _fetchAndMap(String owner, String repo) async {
    final key = '$owner/$repo';
    final models = await _dataSource.fetchPullRequests(owner, repo);
    final entities = models.map((m) => m.toEntity()).toList();
    _cache[key] = entities;
    return entities;
  }
}
