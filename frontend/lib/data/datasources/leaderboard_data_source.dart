/// Data — LeaderboardDataSource
///
/// Abstract datasource interface + remote implementation.
/// LeaderboardRepositoryImpl depends on LeaderboardDataSource (interface),
/// not on the remote HTTP class directly.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/di/service_locator.dart';
import '../../core/logging/app_logger.dart';

// ─── Abstract Interface ──────────────────────────────────────

abstract class LeaderboardDataSource {
  Future<List<dynamic>> fetchLeaderboard();
}

// ─── Remote Implementation ───────────────────────────────────

class RemoteLeaderboardDataSource implements LeaderboardDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteLeaderboardDataSource({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// GET /api/scores/leaderboard
  @override
  Future<List<dynamic>> fetchLeaderboard() async {
    final url = Uri.parse('$baseUrl/api/scores/leaderboard');
    sl.get<AppLogger>().network('LeaderboardDataSource', 'GET', url);

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Leaderboard fetch failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body);
    if (body is List) {
        return body;
    } else if (body is Map) {
        return body['data'] as List<dynamic>? ?? body['entries'] as List<dynamic>? ?? [];
    }
    return [];
  }
}
