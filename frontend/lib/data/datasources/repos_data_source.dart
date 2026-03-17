/// Data — ReposDataSource
///
/// Abstract datasource interface + remote implementation.
library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/repo_info.dart';

// ─── Abstract Interface ──────────────────────────────────────

abstract class ReposDataSource {
  Future<List<RepoInfo>> fetchRepositories();
}

// ─── Remote Implementation ───────────────────────────────────

@Injectable(as: ReposDataSource, env: [Environment.prod])
class RemoteReposDataSource implements ReposDataSource {
  final Dio _dio;

  RemoteReposDataSource(this._dio);

  /// GET /api/repos
  @override
  Future<List<RepoInfo>> fetchRepositories() async {
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

    return repoList.map((r) {
      final m = r as Map<String, dynamic>;
      return RepoInfo(
        name: m['name'] as String? ?? '',
        fullName: m['full_name'] as String? ?? '',
        description: m['description'] as String?,
      );
    }).toList();
  }
}
