/// Domain — LeaderboardRepository
///
/// Abstract contract for leaderboard data.
/// Presentation layer depends ONLY on this interface — never on impl.
library;

import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Fetch server-computed leaderboard for [owner]/[repo].
  Future<List<LeaderboardEntry>> getLeaderboard(String owner, String repo);
}
