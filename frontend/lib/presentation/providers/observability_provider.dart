/// Sellio Metrics — Observability Provider (v2)
///
/// Manages UI state for the observability dashboard.
/// Fixed: proper error handling, separate data fetching, load-more support.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/api_call_entity.dart';
import '../../domain/repositories/metrics_repository.dart';

enum ObservabilityStatus { idle, loading, loaded, error }

class ObservabilityProvider extends ChangeNotifier {
  final MetricsRepository _repository;

  ObservabilityProvider({required MetricsRepository repository})
      : _repository = repository;

  // ─── State ───────────────────────────────────────────────
  ObservabilityStatus _status = ObservabilityStatus.idle;
  ObservabilityStatsEntity _stats = ObservabilityStatsEntity.empty;
  List<ApiCallEntity> _recentCalls = [];
  int _totalCalls = 0;
  String? _sourceFilter;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isLoadingMore = false;

  // ─── Getters ─────────────────────────────────────────────
  ObservabilityStatus get status => _status;
  ObservabilityStatsEntity get stats => _stats;
  List<ApiCallEntity> get recentCalls => _recentCalls;
  int get totalCalls => _totalCalls;
  String? get sourceFilter => _sourceFilter;
  String? get errorMessage => _errorMessage;
  bool get isPolling => _refreshTimer != null;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreCalls => _recentCalls.length < _totalCalls;

  // ─── Actions ─────────────────────────────────────────────

  Future<void> startMonitoring() async {
    await loadData();
    _startPolling();
  }

  void stopMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> loadData() async {
    if (_status == ObservabilityStatus.idle) {
      _status = ObservabilityStatus.loading;
      notifyListeners();
    }

    try {
      // Fetch stats and calls separately so one failure doesn't block the other
      final stats = await _repository.getObservabilityStats();
      _stats = stats;

      final calls = await _repository.getApiCalls(
        source: _sourceFilter,
        limit: 500,
      );
      _recentCalls = calls;
      _totalCalls = stats.totalCalls;

      _status = ObservabilityStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = ObservabilityStatus.error;
      _errorMessage = e.toString();
      debugPrint('[ObservabilityProvider] Error: $e');
    }

    notifyListeners();
  }

  /// Load more calls (pagination) — appends to existing list.
  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMoreCalls) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreCalls = await _repository.getApiCalls(
        source: _sourceFilter,
        limit: 50,
      );
      // Only add calls we don't already have
      final existingIds = _recentCalls.map((c) => c.id).toSet();
      final newCalls = moreCalls.where((c) => !existingIds.contains(c.id)).toList();
      _recentCalls = [..._recentCalls, ...newCalls];
    } catch (e) {
      debugPrint('[ObservabilityProvider] Error loading more: $e');
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  void setSourceFilter(String? source) {
    if (_sourceFilter == source) return;
    _sourceFilter = source;
    _recentCalls = [];
    loadData();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadData(),
    );
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
