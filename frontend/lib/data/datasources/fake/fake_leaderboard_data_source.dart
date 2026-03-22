import 'package:injectable/injectable.dart';
import '../../models/leaderboard/leaderboard_model.dart';
import '../leaderboard/leaderboard_data_source.dart';

@Injectable(as: LeaderboardDataSource, env: [Environment.dev])
class FakeLeaderboardDataSource implements LeaderboardDataSource {
  @override
  Future<List<LeaderboardModel>> fetchLeaderboard() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final json = [
      {
        'developer_id': 'alice',
        'avatarUrl': 'https://avatars.githubusercontent.com/u/1?v=4',
        'event_counts': {
          'PR_CREATED': 12,
          'PR_MERGED': 10,
          'COMMENT': 15,
        },
        'line_additions': 12000,
        'line_deletions': 4000,
        'total_points': 16062.0,
      },
      {
        'developer_id': 'bob',
        'avatarUrl': 'https://avatars.githubusercontent.com/u/2?v=4',
        'event_counts': {
          'PR_CREATED': 8,
          'PR_MERGED': 6,
          'COMMENT': 9,
        },
        'line_additions': 8000,
        'line_deletions': 2000,
        'total_points': 10045.0,
      },
    ];
    return json.map((e) => LeaderboardModel.fromJson(e)).toList();
  }
}
