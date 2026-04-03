import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/models/repo/repo_model.dart';
import 'package:sellio_metrics/data/datasources/repo/repos_data_source.dart';

@Injectable(as: ReposDataSource, env: [Environment.prod])
class ReposDataSourceImpl implements ReposDataSource {
  final ApiClient _apiClient;

  ReposDataSourceImpl(this._apiClient);

  @override
  Future<List<RepoModel>> fetchRepositories() async {
    return await _apiClient.get<List<RepoModel>>(
      ApiEndpoints.reposSynced,          // D1-backed — carries integer IDs
      tag: 'ReposDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final repoList = body['repos'] as List<dynamic>? ?? [];
        return repoList.map((r) => RepoModel.fromJson(r as Map<String, dynamic>)).toList();
      },
    );
  }

  @override
  Future<List<RepoModel>> fetchGithubRepositories() async {
    return await _apiClient.get<List<RepoModel>>(
      ApiEndpoints.repos,                // GitHub-backed — raw org repos
      tag: 'ReposDataSource_GitHub',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final repoList = body['repos'] as List<dynamic>? ?? [];
        return repoList.map((r) => RepoModel.fromJson(r as Map<String, dynamic>)).toList();
      },
    );
  }

  @override
  Future<Map<String, dynamic>> syncGithub(String repoFullName, {List<int>? prNumbers, bool force = false}) async {
    final parts = repoFullName.split('/');
    final owner = parts.length == 2 ? parts[0] : null;
    final repoName = parts.length == 2 ? parts[1] : repoFullName;

    return await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.syncGithub,
      tag: 'SyncGithub',
      data: {
        'repo': repoName,
        if (owner != null) 'owner': owner,
        if (prNumbers != null && prNumbers.isNotEmpty) 'prNumbers': prNumbers,
        if (force) 'force': true,
      },
    );
  }

  @override
  Future<void> syncGithubReset() async {
    await _apiClient.delete<dynamic>(
      ApiEndpoints.syncGithubReset,
      tag: 'SyncGithubReset',
    );
  }

  @override
  Future<void> syncGithubCache() async {
    await _apiClient.delete<dynamic>(
      ApiEndpoints.syncGithubCache,
      tag: 'SyncGithubCache',
    );
  }

  @override
  Future<Map<String, dynamic>> enqueueSyncJobs(List<String> repoFullNames, {bool force = false}) async {
    // Backend accepts repos as string list + optional owner prefix
    final repos = repoFullNames.map((r) => r.split('/').last).toList();
    final owners = repoFullNames.map((r) {
      final parts = r.split('/');
      return parts.length == 2 ? parts[0] : null;
    }).toSet();
    final owner = owners.length == 1 ? owners.first : null;

    return await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.syncGithub,
      tag: 'EnqueueSyncJobs',
      data: {
        'repos': repos,
        if (owner != null) 'owner': owner,
        if (force) 'force': true,
      },
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  @override
  Future<Map<String, dynamic>> getSyncJobStatus(String jobId) async {
    return await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.syncJobStatus(jobId),
      tag: 'SyncJobStatus',
      parser: (data) => data as Map<String, dynamic>,
    );
  }
}
