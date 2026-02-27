/// Sellio Metrics — Remote Data Source
///
/// Fetches PR metrics and repository data from the TypeScript backend,
/// which in turn calls the GitHub API using the Sellio bot credentials.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/pr_model.dart';

/// Contract for metrics data sources.
abstract class MetricsDataSource {
  Future<List<PrModel>> fetchPullRequests(String owner, String repo);
  Future<List<RepoModel>> fetchRepositories();
  Future<List<dynamic>> calculateLeaderboard(List<Map<String, dynamic>> prData);
  Future<Map<String, dynamic>> fetchObservabilityStats();
  Future<List<dynamic>> fetchApiCalls({String? source, int limit = 50});
}

/// A lightweight model for repository info from the backend.
class RepoModel {
  final String name;
  final String fullName;
  final String? description;
  final String htmlUrl;
  final bool isPrivate;

  const RepoModel({
    required this.name,
    required this.fullName,
    this.description,
    required this.htmlUrl,
    required this.isPrivate,
  });

  factory RepoModel.fromJson(Map<String, dynamic> json) => RepoModel(
        name: json['name'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        description: json['description'] as String?,
        htmlUrl: json['html_url'] as String? ?? '',
        isPrivate: json['private'] as bool? ?? false,
      );
}

/// Fetches data from the TypeScript backend (Express + Octokit).
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

  // ─── Observability ──────────────────────────────────────

  @override
  Future<Map<String, dynamic>> fetchObservabilityStats() async {
    final url = Uri.parse('$baseUrl/api/observability/stats');
    debugPrint('[RemoteDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch observability stats: ${response.statusCode} ${response.body}',
      );
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> fetchApiCalls({String? source, int limit = 50}) async {
    final params = <String, String>{
      'limit': limit.toString(),
      if (source != null) 'source': source,
    };
    final url = Uri.parse('$baseUrl/api/observability/calls')
        .replace(queryParameters: params);
    debugPrint('[RemoteDataSource] GET $url');

    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch API calls: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> body =
        json.decode(response.body) as Map<String, dynamic>;
    return body['calls'] as List<dynamic>? ?? [];
  }
}

