import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/logging/app_logger.dart';
import '../leaderboard_data_source.dart';
import '../../models/leaderboard_model.dart';

@Injectable(as: LeaderboardDataSource, env: [Environment.prod])
class RemoteLeaderboardDataSource implements LeaderboardDataSource {
  final Dio _dio;

  RemoteLeaderboardDataSource(this._dio);

  @override
  Future<List<LeaderboardModel>> fetchLeaderboard() async {
    const url = '/api/scores/leaderboard?period=all';
    appLogger.network('LeaderboardDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Leaderboard fetch failed: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data;
    List<dynamic> rawList = [];
    if (body is List) {
      rawList = body;
    } else if (body is Map) {
      rawList = body['data'] as List<dynamic>? ?? body['entries'] as List<dynamic>? ?? [];
    }

    return rawList.map((e) => LeaderboardModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
