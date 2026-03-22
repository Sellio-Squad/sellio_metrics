import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../health_data_source.dart';
import '../../models/kv_cache_quota_model.dart';

@Injectable(as: HealthDataSource, env: [Environment.prod])
class RemoteHealthDataSource implements HealthDataSource {
  final Dio _dio;

  RemoteHealthDataSource(this._dio);

  @override
  Future<Map<String, dynamic>?> fetchHealthStatus() async {
    try {
      final response = await _dio.get('/api/health').timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KvCacheQuotaModel?> fetchCacheQuota() async {
    try {
      final response = await _dio.get('/api/debug/cache-quota').timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return KvCacheQuotaModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
