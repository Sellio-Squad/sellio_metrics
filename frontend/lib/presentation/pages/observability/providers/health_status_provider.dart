import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/gemini_usage_entity.dart';
import 'package:sellio_metrics/domain/entities/github_rate_limit_status.dart';
import 'package:sellio_metrics/domain/entities/kv_cache_quota_status.dart';
import 'package:sellio_metrics/domain/repositories/health_repository.dart';

@injectable
class HealthStatusProvider extends ChangeNotifier {
  final HealthRepository _repository;
  Timer? _refreshTimer;

  GitHubRateLimitStatus? _rateLimit;
  KvCacheQuotaStatus? _cacheQuota;
  GeminiUsageEntity? _geminiUsage;
  bool _isLoading = true;
  String? _error;

  GitHubRateLimitStatus? get rateLimit => _rateLimit;
  KvCacheQuotaStatus? get cacheQuota => _cacheQuota;
  GeminiUsageEntity? get geminiUsage => _geminiUsage;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HealthStatusProvider(this._repository);

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getRateLimitStatus(),
        _repository.getCacheQuotaStatus(),
        _repository.getGeminiUsage(),
      ]);
      _rateLimit = results[0] as GitHubRateLimitStatus?;
      _cacheQuota = results[1] as KvCacheQuotaStatus?;
      _geminiUsage = results[2] as GeminiUsageEntity?;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 60)}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) => fetchAll());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
