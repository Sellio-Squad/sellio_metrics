/// Data — LeaderboardDataSource
///
/// Abstract datasource interface + remote implementation.
/// LeaderboardRepositoryImpl depends on LeaderboardDataSource (interface),
/// not on the remote HTTP class directly.
library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/app_logger.dart';

// ─── Abstract Interface ──────────────────────────────────────

abstract class LeaderboardDataSource {
  Future<List<dynamic>> fetchLeaderboard();
}

// ─── Remote Implementation ───────────────────────────────────

@Injectable(as: LeaderboardDataSource, env: [Environment.prod])
class RemoteLeaderboardDataSource implements LeaderboardDataSource {
  final Dio _dio;

  RemoteLeaderboardDataSource(this._dio);

  /// GET /api/scores/leaderboard
  @override
  Future<List<dynamic>> fetchLeaderboard() async {
    final url = '/api/scores/leaderboard';
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
