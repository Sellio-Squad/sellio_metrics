import 'package:sellio_metrics/domain/entities/repo_info.dart';

abstract class ReposRepository {
  /// Fetch synced repos from D1 — includes integer IDs, name and description.
  Future<List<RepoInfo>> getRepositories();

  /// Fetch all raw GitHub repos for discovery/sync selection
  Future<List<RepoInfo>> getGithubRepositories();

  /// Sync GitHub repo data to D1
  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false});
  
  /// Reset all synced GitHub data
  Future<void> syncGithubReset();

  /// Invalidate API caches
  Future<void> syncGithubCache();
}
