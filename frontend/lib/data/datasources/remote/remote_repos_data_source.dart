import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/logging/app_logger.dart';
import '../repos_data_source.dart';
import '../../models/repo_model.dart';

@Injectable(as: ReposDataSource, env: [Environment.prod])
class RemoteReposDataSource implements ReposDataSource {
  final Dio _dio;

  RemoteReposDataSource(this._dio);

  @override
  Future<List<RepoModel>> fetchRepositories() async {
    final url = '/api/repos';
    appLogger.network('ReposDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Repos fetch failed: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data as Map<String, dynamic>;
    final repoList = body['repos'] as List<dynamic>? ?? [];

    return repoList.map((r) => RepoModel.fromJson(r as Map<String, dynamic>)).toList();
  }
}
