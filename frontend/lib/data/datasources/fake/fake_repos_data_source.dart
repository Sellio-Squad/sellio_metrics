import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/data/models/repo/repo_model.dart';
import 'package:sellio_metrics/data/datasources/repo/repos_data_source.dart';


@Injectable(as: ReposDataSource, env: [Environment.dev])
class FakeReposDataSource implements ReposDataSource {
  @override
  Future<List<RepoModel>> fetchRepositories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      RepoModel(
        id: 1,
        name: ApiConfig.defaultRepo,
        fullName: '${ApiConfig.defaultOrg}/${ApiConfig.defaultRepo}',
        description: 'Fake repo for local metrics preview',
      ),
      RepoModel(
        id: 2,
        name: 'sellio_backend',
        fullName: '${ApiConfig.defaultOrg}/sellio_backend',
        description: 'Fake backend repo',
      ),
    ];
  }

  @override
  Future<List<RepoModel>> fetchGithubRepositories() async {
    return await fetchRepositories();
  }

  @override
  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'prsUpserted': 5,
      'commentsInserted': 12,
      'linesAdded': 1500,
      'linesDeleted': 300,
      'fetchFailures': [],
    };
  }

  @override
  Future<void> syncGithubReset() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> syncGithubCache() async {
    // Fake invalidate cache response
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<Map<String, dynamic>> enqueueSyncJobs(List<String> repoFullNames, {bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'ok': true,
      'message': 'Sync jobs enqueued',
      'jobs': repoFullNames.map((r) => {
        'jobId': 'fake-job-${r.hashCode}',
        'repo': r,
      }).toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> getSyncJobStatus(String jobId) async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'jobId': jobId,
      'status': 'done',
      'result': {
        'prsUpserted': 5,
        'commentsInserted': 12,
        'linesAdded': 1500,
        'linesDeleted': 300,
      },
    };
  }
}
