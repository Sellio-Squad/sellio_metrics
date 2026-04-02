/// Domain — LeaderboardRepository
///
/// Abstract contract for leaderboard data.
/// Presentation layer depends ONLY on this interface — never on impl.

import 'package:sellio_metrics/domain/entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Fetch server-computed leaderboard, optionally filtered.
  Future<List<LeaderboardEntry>> getLeaderboard({
    String? since,
    String? until,
    List<int>? repoIds,
  });
}
