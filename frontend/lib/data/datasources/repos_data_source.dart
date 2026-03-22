import '../models/repo_model.dart';

abstract class ReposDataSource {
  Future<List<RepoModel>> fetchRepositories();
}
