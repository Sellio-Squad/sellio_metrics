import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/pr_model.dart';
import 'local_data_source.dart';

class RemoteDataSource implements MetricsDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteDataSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<List<PrModel>> fetchPullRequests(String owner, String repo) async {
    final url = Uri.parse('$baseUrl/api/metrics/$owner/$repo?state=all');
    debugPrint('[RemoteDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch PR metrics: ${response.statusCode} ${response.body}',
      );
    }

    // Backend returns an envelope: { "count": N, "metrics": [...] }
    final Map<String, dynamic> body =
    json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> jsonList = body['metrics'] as List<dynamic>? ?? [];

    return jsonList
        .map((e) => PrModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<RepoModel>> fetchRepositories() async {
    final url = Uri.parse('$baseUrl/api/repos');
    debugPrint('[RemoteDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch repositories: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
    json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> repoList = body['repos'] as List<dynamic>;
    return repoList
        .map((e) => RepoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<dynamic>> calculateLeaderboard(List<Map<String, dynamic>> prData) async {
    final url = Uri.parse('$baseUrl/api/metrics/leaderboard');
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'prs': prData}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to calculate leaderboard on backend: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as List<dynamic>;
  }
}