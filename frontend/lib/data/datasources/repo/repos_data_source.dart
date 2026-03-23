import 'package:sellio_metrics/data/models/repo/repo_model.dart';

abstract class ReposDataSource {
  Future<List<RepoModel>> fetchRepositories();
}
