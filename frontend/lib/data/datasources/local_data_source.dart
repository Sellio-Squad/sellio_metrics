library;

import '../models/pr_model.dart';

abstract class MetricsDataSource {
  Future<List<PrModel>> fetchPullRequests(String owner, String repo);
  Future<List<RepoModel>> fetchRepositories();
  Future<List<dynamic>> calculateLeaderboard(List<Map<String, dynamic>> prData);
}

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