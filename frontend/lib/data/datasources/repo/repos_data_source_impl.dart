import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/repo/repo_model.dart';
import 'repos_data_source.dart';

@Injectable(as: ReposDataSource, env: [Environment.prod])
class ReposDataSourceImpl implements ReposDataSource {
  final ApiClient _apiClient;

  ReposDataSourceImpl(this._apiClient);

  @override
  Future<List<RepoModel>> fetchRepositories() async {
    return await _apiClient.get<List<RepoModel>>(
      '/api/repos',
      tag: 'ReposDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final repoList = body['repos'] as List<dynamic>? ?? [];
        return repoList.map((r) => RepoModel.fromJson(r as Map<String, dynamic>)).toList();
      },
    );
  }
}
