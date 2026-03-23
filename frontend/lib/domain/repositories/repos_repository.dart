import 'package:sellio_metrics/domain/entities/repo_info.dart';

abstract class ReposRepository {
  /// Fetch available repos for the configured organisation.
  Future<List<RepoInfo>> getRepositories();
}
