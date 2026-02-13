library;

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pr_model.dart';

abstract class MetricsDataSource {
  Future<List<PrModel>> fetchPullRequests();
}

/// Loads PR data from a local JSON asset file.
///
/// Primary data source — reads from the pre-generated `pr_metrics.json`
/// committed by the CI bot.
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

/// Placeholder for future remote API integration (GitHub REST/GraphQL).
///
/// When ready, this will use `http` or `dio` to call the GitHub API
/// and map responses to [PrModel] instances.
class RemoteDataSource implements MetricsDataSource {
  @override
  Future<List<PrModel>> fetchPullRequests() async {
    throw UnimplementedError(
      'Remote API integration is not yet implemented. '
      'Use LocalDataSource for now.',
    );
  }
}
