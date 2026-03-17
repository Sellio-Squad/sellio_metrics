/// Data — MembersDataSource
///
/// Abstract datasource interface + remote implementation.
library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../core/logging/app_logger.dart';

// ─── Abstract Interface ──────────────────────────────────────

abstract class MembersDataSource {
  Future<List<dynamic>> fetchMembersStatus();
}

// ─── Remote Implementation ───────────────────────────────────

@Injectable(as: MembersDataSource, env: [Environment.prod])
class RemoteMembersDataSource implements MembersDataSource {
  final Dio _dio;

  RemoteMembersDataSource(this._dio);

  /// GET /api/members
  @override
  Future<List<dynamic>> fetchMembersStatus() async {
    final url = '/api/members';
    appLogger.network('MembersDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Members fetch failed: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data as Map<String, dynamic>;
    return body['data'] as List<dynamic>? ?? body['members'] as List<dynamic>? ?? [];
  }
}
