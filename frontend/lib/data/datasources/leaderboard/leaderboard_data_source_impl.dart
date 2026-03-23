import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/models/leaderboard/leaderboard_model.dart';
import 'package:sellio_metrics/data/datasources/leaderboard/leaderboard_data_source.dart';

@Injectable(as: LeaderboardDataSource, env: [Environment.prod])
class LeaderboardDataSourceImpl implements LeaderboardDataSource {
  final ApiClient _apiClient;

  LeaderboardDataSourceImpl(this._apiClient);

  @override
  Future<List<LeaderboardModel>> fetchLeaderboard() async {
    return await _apiClient.get<List<LeaderboardModel>>(
      ApiEndpoints.leaderboard,
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
