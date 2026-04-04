import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/issues/issues_data_source.dart';

@Injectable(as: IssuesDataSource, env: [Environment.prod])
class IssuesDataSourceImpl implements IssuesDataSource {
  final ApiClient _apiClient;

  IssuesDataSourceImpl(this._apiClient);

  @override
  Future<List<dynamic>> fetchOpenIssues({required String org}) async {
    return await _apiClient.get<List<dynamic>>(
      ApiEndpoints.issues,
      tag: 'open-issues',
      parser: (data) {
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'] as List<dynamic>;
        }
        return [];
      },
    );
  }
}
