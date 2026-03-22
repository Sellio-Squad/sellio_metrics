import '../models/leaderboard_model.dart';

abstract class LeaderboardDataSource {
  Future<List<LeaderboardModel>> fetchLeaderboard();
}
