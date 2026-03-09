/// Data — ReposRepositoryImpl
///
/// Implements the domain ReposRepository interface.
/// Depends on ReposDataSource (interface, not concrete).
library;

import '../../domain/entities/repo_info.dart';
import '../../domain/repositories/repos_repository.dart';
import '../datasources/repos_data_source.dart';

class ReposRepositoryImpl implements ReposRepository {
  final ReposDataSource _dataSource;

  ReposRepositoryImpl({required ReposDataSource dataSource})
    : _dataSource = dataSource;

  @override
  Future<List<RepoInfo>> getRepositories() => _dataSource.fetchRepositories();
}
