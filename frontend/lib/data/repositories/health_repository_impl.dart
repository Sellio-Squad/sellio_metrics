import 'package:injectable/injectable.dart';

import '../../domain/entities/github_rate_limit_status.dart';
import '../../domain/entities/kv_cache_quota_status.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_data_source.dart';
import '../mappers/health_mappers.dart';
import '../models/github_rate_limit_model.dart';

@LazySingleton(as: HealthRepository)
class HealthRepositoryImpl implements HealthRepository {
  final HealthDataSource _dataSource;

  HealthRepositoryImpl(this._dataSource);

  @override
  Future<GitHubRateLimitStatus?> getRateLimitStatus() async {
    final body = await _dataSource.fetchHealthStatus();
    if (body == null) return null;
    final rateJson = body['githubRateLimit'];
    if (rateJson is! Map<String, dynamic>) return null;
    return GitHubRateLimitModel.fromJson(rateJson).toEntity();
  }

  @override
  Future<KvCacheQuotaStatus?> getCacheQuotaStatus() async {
    final body = await _dataSource.fetchCacheQuota();
    if (body == null) return null;
    return body.toEntity();
  }
}
