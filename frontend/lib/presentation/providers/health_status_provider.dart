import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/github_rate_limit_status.dart';
import '../../domain/entities/kv_cache_quota_status.dart';
import '../../domain/repositories/health_repository.dart';

class HealthStatusProvider extends ChangeNotifier {
  final HealthRepository _repository;
  Timer? _refreshTimer;

  GitHubRateLimitStatus? _rateLimit;
  KvCacheQuotaStatus? _cacheQuota;
  bool _isLoading = true;
  String? _error;

  GitHubRateLimitStatus? get rateLimit => _rateLimit;
  KvCacheQuotaStatus? get cacheQuota => _cacheQuota;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HealthStatusProvider({required HealthRepository repository})
      : _repository = repository;

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getRateLimitStatus(),
        _repository.getCacheQuotaStatus(),
      ]);
      _rateLimit = results[0] as GitHubRateLimitStatus?;
      _cacheQuota = results[1] as KvCacheQuotaStatus?;
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
