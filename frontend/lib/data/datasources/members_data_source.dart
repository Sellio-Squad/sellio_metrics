/// Data — MembersDataSource
///
/// Abstract datasource interface + remote implementation.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Abstract Interface ──────────────────────────────────────

abstract class MembersDataSource {
  Future<List<dynamic>> fetchMembersStatus(String owner, String repo);
}

// ─── Remote Implementation ───────────────────────────────────

class RemoteMembersDataSource implements MembersDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteMembersDataSource({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// GET /api/metrics/:owner/:repo/members
  @override
  Future<List<dynamic>> fetchMembersStatus(String owner, String repo) async {
    final url = Uri.parse('$baseUrl/api/metrics/$owner/$repo/members');
    debugPrint('[MembersDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Members fetch failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? body['members'] as List<dynamic>? ?? [];
  }
}
