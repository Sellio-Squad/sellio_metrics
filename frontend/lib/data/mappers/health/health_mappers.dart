import 'package:sellio_metrics/domain/entities/github_rate_limit_status.dart';
import 'package:sellio_metrics/domain/entities/kv_cache_quota_status.dart';
import 'package:sellio_metrics/data/models/health/github_rate_limit_model.dart';
import 'package:sellio_metrics/data/models/health/kv_cache_quota_model.dart';


extension GitHubRateLimitModelMapper on GitHubRateLimitModel {
  GitHubRateLimitStatus toEntity() {
    return GitHubRateLimitStatus(
      remaining: remaining,
      limit: limit,
      resetAtIso: resetAtIso,
      isLow: isLow,
    );
  }
}

extension KvCacheQuotaModelMapper on KvCacheQuotaModel {
  KvCacheQuotaStatus toEntity() {
    return KvCacheQuotaStatus(
      kvFreeWriteLimit: kvFreeWriteLimit,
      kvResetAtUtc: kvResetAtUtc,
      kvSecondsToReset: kvSecondsToReset,
      cachedKeys: cachedKeys,
      maxWritesPerRequest: maxWritesPerRequest,
    );
  }
}
