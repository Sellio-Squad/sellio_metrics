/// Sellio Metrics — Data Source Abstraction
///
/// Interface for fetching PR data from different sources.
/// Follows the Dependency Inversion Principle — domain depends on abstraction,
/// not on concrete implementations.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/pr_model.dart';

/// Abstract data source for metrics data.
abstract class MetricsDataSource {
  /// Fetches all pull requests.
  Future<List<PrModel>> fetchPullRequests();
}

/// Loads PR data from a local JSON asset file.
///
/// This is the primary data source when the dashboard reads from
/// the pre-generated `pr_metrics.json` committed by the CI bot.
class LocalDataSource implements MetricsDataSource {
  static const String _assetPath = 'assets/data/pr_metrics.json';

  @override
  Future<List<PrModel>> fetchPullRequests() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => PrModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Placeholder for future GitHub API integration.
///
/// When ready, this will use `http` or `dio` to call the GitHub REST/GraphQL
/// API and map responses to [PrModel] instances.
class GitHubDataSource implements MetricsDataSource {
  // Future: final String accessToken;
  // Future: final String repoOwner;
  // Future: final String repoName;

  @override
  Future<List<PrModel>> fetchPullRequests() async {
    // TODO: Implement GitHub API fetching
    throw UnimplementedError(
      'GitHub API integration is not yet implemented. '
      'Use LocalDataSource for now.',
    );
  }
}
