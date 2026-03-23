import 'package:sellio_metrics/domain/entities/repo_info.dart';

abstract class ReposRepository {
  /// Fetch available repos for the configured organisation.
  Future<List<RepoInfo>> getRepositories();

  /// Sync GitHub repo data to D1
  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false});
  
  /// Reset all synced GitHub data
  Future<void> syncGithubReset();
}
