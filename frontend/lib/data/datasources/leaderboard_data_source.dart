library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../core/logging/app_logger.dart';

abstract class LeaderboardDataSource {
  Future<List<dynamic>> fetchLeaderboard();
}

@Injectable(as: LeaderboardDataSource, env: [Environment.prod])
class RemoteLeaderboardDataSource implements LeaderboardDataSource {
  final Dio _dio;

  RemoteLeaderboardDataSource(this._dio);

  @override
  Future<List<dynamic>> fetchLeaderboard() async {
    const url = '/api/scores/leaderboard?period=all';
    appLogger.network('LeaderboardDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Leaderboard fetch failed: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data;
    if (body is List) {
        return body;
    } else if (body is Map) {
        return body['data'] as List<dynamic>? ?? body['entries'] as List<dynamic>? ?? [];
    }
    return [];
  }
}
