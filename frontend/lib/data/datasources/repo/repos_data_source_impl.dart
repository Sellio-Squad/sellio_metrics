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
}
