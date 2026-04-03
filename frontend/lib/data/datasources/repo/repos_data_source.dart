import 'package:sellio_metrics/data/models/repo/repo_model.dart';

abstract class ReposDataSource {
  Future<List<RepoModel>> fetchRepositories();
  Future<List<RepoModel>> fetchGithubRepositories();

  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false});
  Future<void> syncGithubReset();
  Future<void> syncGithubCache();
  Future<Map<String, dynamic>> enqueueSyncJobs(List<String> repoFullNames, {bool force = false});
  Future<Map<String, dynamic>> getSyncJobStatus(String jobId);
}
