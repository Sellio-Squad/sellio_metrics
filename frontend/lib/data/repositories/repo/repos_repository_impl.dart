import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/repositories/repos_repository.dart';
import 'package:sellio_metrics/data/datasources/repo/repos_data_source.dart';
import 'package:sellio_metrics/data/mappers/repo/repo_mappers.dart';

@LazySingleton(as: ReposRepository)
class ReposRepositoryImpl implements ReposRepository {
  final ReposDataSource _dataSource;

  ReposRepositoryImpl(this._dataSource);

  @override
  Future<List<RepoInfo>> getRepositories() async {
    final models = await _dataSource.fetchRepositories();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<RepoInfo>> getGithubRepositories() async {
    final models = await _dataSource.fetchGithubRepositories();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false}) async {
    return await _dataSource.syncGithub(repoFullName, prNumbers: prNumbers, force: force);
  }

  @override
  Future<void> syncGithubReset() async {
    return await _dataSource.syncGithubReset();
  }

  @override
  Future<void> syncGithubCache() async {
    return await _dataSource.syncGithubCache();
  }

  @override
  Future<Map<String, dynamic>> enqueueSyncJobs(List<String> repoFullNames, {bool force = false}) async {
    return await _dataSource.enqueueSyncJobs(repoFullNames, force: force);
  }

  @override
  Future<Map<String, dynamic>> getSyncJobStatus(String jobId) async {
    return await _dataSource.getSyncJobStatus(jobId);
  }
}
