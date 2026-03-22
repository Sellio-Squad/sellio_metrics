import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/health/kv_cache_quota_model.dart';
import 'health_data_source.dart';

@Injectable(as: HealthDataSource, env: [Environment.prod])
class HealthDataSourceImpl implements HealthDataSource {
  final ApiClient _apiClient;

  HealthDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>?> fetchHealthStatus() async {
    try {
      return await _apiClient.get<Map<String, dynamic>>('/api/health');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KvCacheQuotaModel?> fetchCacheQuota() async {
    try {
      return await _apiClient.get<KvCacheQuotaModel>(
        '/api/debug/cache-quota',
        parser: (data) => KvCacheQuotaModel.fromJson(data as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}
