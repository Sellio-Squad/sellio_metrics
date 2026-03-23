import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/datasources/pr/pr_data_source.dart';

@Injectable(as: PrDataSource, env: [Environment.prod])
class PrDataSourceImpl implements PrDataSource {
  final ApiClient _apiClient;

  PrDataSourceImpl(this._apiClient);

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    return await _apiClient.get<List<dynamic>>(
      ApiEndpoints.prs,
      parser: (data) {
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'] as List<dynamic>;
        }
        return [];
      },
    );
  }
}
