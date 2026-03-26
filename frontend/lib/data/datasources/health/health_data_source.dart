import 'package:sellio_metrics/data/models/health/kv_cache_quota_model.dart';
import 'package:sellio_metrics/domain/entities/gemini_usage_entity.dart';

abstract class HealthDataSource {
  Future<Map<String, dynamic>?> fetchHealthStatus();
  Future<KvCacheQuotaModel?> fetchCacheQuota();
  Future<GeminiUsageEntity?> fetchGeminiUsage();
}
