import 'package:sellio_metrics/data/models/health/kv_cache_quota_model.dart';

abstract class HealthDataSource {
  Future<Map<String, dynamic>?> fetchHealthStatus();
  Future<KvCacheQuotaModel?> fetchCacheQuota();
}
