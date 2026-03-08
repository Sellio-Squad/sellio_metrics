/// Data — LeaderboardRepositoryImpl
///
/// Implements the domain LeaderboardRepository interface.
/// Depends on LeaderboardDataSource (interface, not concrete).
/// Maps raw JSON to domain LeaderboardEntry entities.
library;

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_data_source.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardDataSource _dataSource;

  LeaderboardRepositoryImpl({required LeaderboardDataSource dataSource})
    : _dataSource = dataSource;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    String owner,
    String repo,
  ) async {
    final raw = await _dataSource.fetchLeaderboard(owner, repo);
    return raw.map(_toEntity).toList();
  }

  LeaderboardEntry _toEntity(dynamic json) {
    final m = json as Map<String, dynamic>;
    return LeaderboardEntry(
      developer: m['developer'] as String? ?? 'Unknown',
      avatarUrl: m['avatarUrl'] as String?,
      prsCreated: m['prsCreated'] as int? ?? 0,
      prsMerged: m['prsMerged'] as int? ?? 0,
      reviewsGiven: m['reviewsGiven'] as int? ?? 0,
      commentsGiven: m['commentsGiven'] as int? ?? 0,
      additions: m['additions'] as int? ?? 0,
      deletions: m['deletions'] as int? ?? 0,
      totalScore: (m['totalScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
