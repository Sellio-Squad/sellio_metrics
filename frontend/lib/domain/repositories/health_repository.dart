import 'package:sellio_metrics/domain/entities/github_rate_limit_status.dart';
import 'package:sellio_metrics/domain/entities/kv_cache_quota_status.dart';

abstract class HealthRepository {
  Future<GitHubRateLimitStatus?> getRateLimitStatus();
  Future<KvCacheQuotaStatus?> getCacheQuotaStatus();
}
