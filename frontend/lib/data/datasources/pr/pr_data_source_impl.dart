import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import 'pr_data_source.dart';

@Injectable(as: PrDataSource, env: [Environment.prod])
class PrDataSourceImpl implements PrDataSource {
  final ApiClient _apiClient;

  PrDataSourceImpl(this._apiClient);

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    return await _apiClient.get<List<dynamic>>(
      '/api/prs',
      parser: (data) {
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'] as List<dynamic>;
        }
        return [];
      },
    );
  }
}
