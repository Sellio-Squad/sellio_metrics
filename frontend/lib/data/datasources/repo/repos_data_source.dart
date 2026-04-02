import 'package:sellio_metrics/data/models/repo/repo_model.dart';

abstract class ReposDataSource {
  Future<List<RepoModel>> fetchRepositories();

  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false});
  Future<void> syncGithubReset();
}
