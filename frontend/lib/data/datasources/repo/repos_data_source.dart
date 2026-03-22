import '../../models/repo/repo_model.dart';

abstract class ReposDataSource {
  Future<List<RepoModel>> fetchRepositories();
}
