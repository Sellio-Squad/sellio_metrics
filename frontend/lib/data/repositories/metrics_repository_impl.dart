/// Sellio Metrics — Repository Implementation
///
/// Concrete repository that reads from a [MetricsDataSource]
/// and maps data models to domain entities.
library;

import '../datasources/local_data_source.dart';
import '../mappers/pr_mappers.dart';

import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/leaderboard_entry.dart';
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

  @override
  Future<List<LeaderboardEntry>> calculateLeaderboard(List<PrEntity> prs) async {
    final prData = prs.map((pr) => {
      'status': pr.status,
      'creator': {
        'login': pr.creator.login,
        'avatar_url': pr.creator.avatarUrl,
      },
      'approvals': pr.approvals.map((a) => {
        'reviewer': {
          'login': a.reviewer.login,
          'avatar_url': a.reviewer.avatarUrl,
        }
      }).toList(),
      'comments': pr.comments.map((c) => {
        'author': {
          'login': c.author.login,
          'avatar_url': c.author.avatarUrl,
        }
      }).toList(),
      'diff_stats': {
        'additions': pr.diffStats.additions,
        'deletions': pr.diffStats.deletions,
      },
    }).toList();

    final result = await _dataSource.calculateLeaderboard(prData);
    
    return result.map((json) => LeaderboardEntry(
      developer: json['developer'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      prsCreated: json['prsCreated'] as int? ?? 0,
      prsMerged: json['prsMerged'] as int? ?? 0,
      reviewsGiven: json['reviewsGiven'] as int? ?? 0,
      commentsGiven: json['commentsGiven'] as int? ?? 0,
       additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  Future<List<PrEntity>> _fetchAndMap(String owner, String repo) async {
    final key = '$owner/$repo';
    final models = await _dataSource.fetchPullRequests(owner, repo);
    final entities = models.map((m) => m.toEntity()).toList();
    _cache[key] = entities;
    return entities;
  }
}

