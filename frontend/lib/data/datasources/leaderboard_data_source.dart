/// Data — LeaderboardDataSource
///
/// Abstract datasource interface + remote implementation.
/// LeaderboardRepositoryImpl depends on LeaderboardDataSource (interface),
/// not on the remote HTTP class directly.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Abstract Interface ──────────────────────────────────────

abstract class LeaderboardDataSource {
  Future<List<dynamic>> fetchLeaderboard(String owner, String repo);
}

// ─── Remote Implementation ───────────────────────────────────

class RemoteLeaderboardDataSource implements LeaderboardDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteLeaderboardDataSource({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// GET /api/metrics/:owner/:repo/leaderboard
  @override
  Future<List<dynamic>> fetchLeaderboard(String owner, String repo) async {
    final url = Uri.parse('$baseUrl/api/metrics/$owner/$repo/leaderboard');
    debugPrint('[LeaderboardDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Leaderboard fetch failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? body['entries'] as List<dynamic>? ?? [];
  }
}
