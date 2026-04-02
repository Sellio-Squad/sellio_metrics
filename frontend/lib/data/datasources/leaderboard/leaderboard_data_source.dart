import 'package:sellio_metrics/data/models/leaderboard/leaderboard_model.dart';

abstract class LeaderboardDataSource {
  Future<List<LeaderboardModel>> fetchLeaderboard({
    String? since,
    String? until,
    List<int>? repoIds,
  });
}
