import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/leaderboard/leaderboard_model.dart';
import 'leaderboard_data_source.dart';

@Injectable(as: LeaderboardDataSource, env: [Environment.prod])
class LeaderboardDataSourceImpl implements LeaderboardDataSource {
  final ApiClient _apiClient;

  LeaderboardDataSourceImpl(this._apiClient);

  @override
  Future<List<LeaderboardModel>> fetchLeaderboard() async {
    return await _apiClient.get<List<LeaderboardModel>>(
      '/api/scores/leaderboard?period=all',
      tag: 'LeaderboardDataSource',
      parser: (data) {
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          rawList = data['data'] as List<dynamic>? ?? 
                    data['entries'] as List<dynamic>? ?? [];
        }
        return rawList.map((e) => LeaderboardModel.fromJson(e as Map<String, dynamic>)).toList();
      },
    );
  }
}
