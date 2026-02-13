/// Sellio Metrics — Dashboard Provider
///
/// Main state management for the dashboard.
/// Orchestrates data loading, filtering, and computed analytics.
library;

import 'package:flutter/foundation.dart';

import '../../data/models/pr_model.dart';
import '../../data/models/kpi_model.dart';
import '../../data/models/bottleneck_model.dart';
import '../../data/models/collaboration_model.dart';
import '../../data/repositories/metrics_repository.dart';
import '../../domain/services/analytics_service.dart';
import '../../core/constants/app_constants.dart';

enum DashboardStatus { loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  final MetricsRepository _repository;
  final AnalyticsService _analyticsService;

  DashboardProvider({
    MetricsRepository? repository,
    AnalyticsService? analyticsService,
  })  : _repository = repository ?? MetricsRepositoryImpl(),
        _analyticsService = analyticsService ?? const AnalyticsService();

  // ─── State ───────────────────────────────────────────────
  DashboardStatus _status = DashboardStatus.loading;
  List<PrModel> _allPrs = [];
  String _weekFilter = 'all';
  String _developerFilter = 'all';
  String _searchTerm = '';
  String _statusFilter = 'all';
  int _currentPageIndex = 0;
  double _bottleneckThreshold = BottleneckConfig.defaultThresholdHours;

  // ─── Getters ─────────────────────────────────────────────
  DashboardStatus get status => _status;
  List<PrModel> get allPrs => _allPrs;
  String get weekFilter => _weekFilter;
  String get developerFilter => _developerFilter;
  String get searchTerm => _searchTerm;
  String get statusFilter => _statusFilter;
  int get currentPageIndex => _currentPageIndex;
  double get bottleneckThreshold => _bottleneckThreshold;

  /// PRs filtered by week only (used for analytics that need full week data).
  List<PrModel> get weekFilteredPrs =>
      _analyticsService.filterByWeek(_allPrs, _weekFilter);

  /// PRs filtered by week + search + status (for PR lists).
  List<PrModel> get filteredPrs => _analyticsService.filterPrs(
        weekFilteredPrs,
        searchTerm: _searchTerm,
        statusFilter: _statusFilter,
      );

  /// Open PRs only.
  List<PrModel> get openPrs =>
      filteredPrs.where((pr) => pr.isOpen).toList();

  // ─── Computed Analytics ──────────────────────────────────
  KpiModel get kpis => _analyticsService.calculateKpis(
        weekFilteredPrs,
        developerFilter: _developerFilter,
      );

  SpotlightModel get spotlightMetrics =>
      _analyticsService.calculateSpotlightMetrics(
        weekFilteredPrs,
        developerFilter: _developerFilter,
      );

  List<BottleneckModel> get bottlenecks => _analyticsService.identifyBottlenecks(
        weekFilteredPrs,
        thresholdHours: _bottleneckThreshold,
      );

  List<CollaborationPair> get collaborationPairs =>
      _analyticsService.calculateCollaborationPairs(weekFilteredPrs);

  List<LeaderboardEntry> get leaderboard =>
      _analyticsService.calculateLeaderboard(weekFilteredPrs);

  List<ReviewLoadEntry> get reviewLoad =>
      _analyticsService.calculateReviewLoad(weekFilteredPrs);

  Map<String, int> get prTypeDistribution =>
      _analyticsService.analyzePrTypes(weekFilteredPrs);

  List<String> get availableWeeks =>
      _analyticsService.getUniqueWeeks(_allPrs);

  List<String> get availableDevelopers =>
      _analyticsService.getUniqueDevelopers(_allPrs);

  // ─── Actions ─────────────────────────────────────────────
  Future<void> loadData() async {
    _status = DashboardStatus.loading;
    notifyListeners();

    try {
      _allPrs = await _repository.getPullRequests();
      _status = DashboardStatus.loaded;
    } catch (e) {
      _status = DashboardStatus.error;
      debugPrint('Error loading PR data: $e');
    }
    notifyListeners();
  }

  void setWeekFilter(String week) {
    _weekFilter = week;
    notifyListeners();
  }

  void setDeveloperFilter(String developer) {
    _developerFilter = developer;
    notifyListeners();
  }

  void setSearchTerm(String term) {
    _searchTerm = term;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setPageIndex(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  void setBottleneckThreshold(double hours) {
    _bottleneckThreshold = hours;
    notifyListeners();
  }
}
