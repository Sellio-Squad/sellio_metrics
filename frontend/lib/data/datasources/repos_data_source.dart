/// Data — ReposDataSource
///
/// Abstract datasource interface + remote implementation.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/repo_info.dart';

// ─── Abstract Interface ──────────────────────────────────────

abstract class ReposDataSource {
  Future<List<RepoInfo>> fetchRepositories();
}

// ─── Remote Implementation ───────────────────────────────────

class RemoteReposDataSource implements ReposDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteReposDataSource({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  /// GET /api/repos
  @override
  Future<List<RepoInfo>> fetchRepositories() async {
    final url = Uri.parse('$baseUrl/api/repos');
    debugPrint('[ReposDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Repos fetch failed: ${response.statusCode} ${response.body}',
      );
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final repoList = body['repos'] as List<dynamic>? ?? [];

    return repoList.map((r) {
      final m = r as Map<String, dynamic>;
      return RepoInfo(
        name: m['name'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        description: m['description'] as String?,
      );
    }).toList();
  }
}
