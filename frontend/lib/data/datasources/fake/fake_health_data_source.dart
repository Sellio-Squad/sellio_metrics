import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/models/health/kv_cache_quota_model.dart';
import 'package:sellio_metrics/data/datasources/health/health_data_source.dart';

@Injectable(as: HealthDataSource, env: [Environment.dev])
class FakeHealthDataSource implements HealthDataSource {
  @override
  Future<Map<String, dynamic>?> fetchHealthStatus() async {
    return {
      'status': 'ok',
      'githubRateLimit': {
        'remaining': 4950,
        'limit': 5000,
        'resetAt': '2026-03-22T12:00:00Z',
        'isLow': false,
      }
    };
  }

  @override
  Future<KvCacheQuotaModel?> fetchCacheQuota() async {
    return const KvCacheQuotaModel(
      kvFreeWriteLimit: 950,
      kvResetAtUtc: '2026-03-22T00:00:00Z',
      kvSecondsToReset: 3600,
      cachedKeys: {'key1': {'hit': true}},
      maxWritesPerRequest: 3,
    );
  }
}
