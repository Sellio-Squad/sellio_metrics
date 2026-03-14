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
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final raw = await _dataSource.fetchLeaderboard();
    return raw.map(_toEntity).toList();
  }

  LeaderboardEntry _toEntity(dynamic json) {
    final m = json as Map<String, dynamic>;
    final counts = m['event_counts'] as Map<String, dynamic>? ?? {};
    
    return LeaderboardEntry(
      developer: m['developer_id'] as String? ?? m['developer'] as String? ?? 'Unknown',
      avatarUrl: m['avatarUrl'] as String?,
      prsCreated: counts['PR_CREATED'] as int? ?? m['prsCreated'] as int? ?? 0,
      prsMerged: counts['PR_MERGED'] as int? ?? m['prsMerged'] as int? ?? 0,
      commentsGiven: counts['COMMENT'] as int? ?? m['commentsGiven'] as int? ?? 0,
      additions: counts['CODE_ADDITION'] as int? ?? m['additions'] as int? ?? 0,
      deletions: counts['CODE_DELETION'] as int? ?? m['deletions'] as int? ?? 0,
      totalScore: (m['total_points'] as num?)?.toDouble() ?? (m['totalScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
