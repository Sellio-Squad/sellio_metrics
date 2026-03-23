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
      ApiEndpoints.repos,
      tag: 'ReposDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final repoList = body['repos'] as List<dynamic>? ?? [];
        return repoList.map((r) => RepoModel.fromJson(r as Map<String, dynamic>)).toList();
      },
    );
  }
}
