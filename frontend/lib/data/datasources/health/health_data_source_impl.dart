import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/models/health/kv_cache_quota_model.dart';
import 'package:sellio_metrics/data/datasources/health/health_data_source.dart';
import 'package:sellio_metrics/domain/entities/gemini_usage_entity.dart';

@Injectable(as: HealthDataSource, env: [Environment.prod])
class HealthDataSourceImpl implements HealthDataSource {
  final ApiClient _apiClient;

  HealthDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>?> fetchHealthStatus() async {
    try {
      return await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.health);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KvCacheQuotaModel?> fetchCacheQuota() async {
    try {
      // Fetch both in parallel for speed
      final results = await Future.wait<Map<String, dynamic>?>([
        _apiClient.get<Map<String, dynamic>>(ApiEndpoints.cacheQuota),
        fetchLogQuota(),
      ]);
      final cacheJson = results[0];
      final quotaJson = results[1];
      if (cacheJson == null) return null;

      // Merge write count from /api/logs/quota into the cache quota model
      final merged = {
        ...cacheJson,
        'writesTotal':       quotaJson?['writesTotal']       ?? 0,
        'writesThisIsolate': quotaJson?['writesThisIsolate'] ?? 0,
      };
      return KvCacheQuotaModel.fromJson(merged);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GeminiUsageEntity?> fetchGeminiUsage() async {
    try {
      return await _apiClient.get<GeminiUsageEntity>(
        ApiEndpoints.reviewUsage,
        parser: (data) => GeminiUsageEntity.fromJson(data as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchLogQuota() async {
    try {
      return await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.logsQuota,
        parser: (data) => data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }
}
