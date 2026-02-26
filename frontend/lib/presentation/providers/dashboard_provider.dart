library;

import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/kpi_entity.dart';
import '../../domain/entities/bottleneck_entity.dart';
import '../../domain/repositories/metrics_repository.dart';
import '../../domain/services/kpi_service.dart';
import '../../domain/services/bottleneck_service.dart';
import '../../domain/services/collaboration_service.dart';
import '../../domain/services/filter_service.dart';

enum DashboardStatus { loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  final MetricsRepository _repository;
  final KpiService _kpiService;
  final BottleneckService _bottleneckService;
  final CollaborationService _collaborationService;
  final FilterService _filterService;

  DashboardProvider({
    required MetricsRepository repository,
    required KpiService kpiService,
    required BottleneckService bottleneckService,
    required CollaborationService collaborationService,
    required FilterService filterService,
  }) : _repository = repository,
       _kpiService = kpiService,
       _bottleneckService = bottleneckService,
       _collaborationService = collaborationService,
       _filterService = filterService;

  // ─── State ───────────────────────────────────────────────
  DashboardStatus _status = DashboardStatus.loading;
  List<PrEntity> _allPrs = [];
  String _weekFilter = FilterOptions.all;
  String _developerFilter = FilterOptions.all;
  String _searchTerm = '';
  String _statusFilter = FilterOptions.all;
  int _currentPageIndex = 0;
  double _bottleneckThreshold = BottleneckConfig.defaultThresholdHours;
  DateTime? _startDate;
  DateTime? _endDate;

  /// Current repos being displayed.
  List<RepoInfo> _currentRepos = [];

  // ─── Getters ─────────────────────────────────────────────
  DashboardStatus get status => _status;

  List<PrEntity> get allPrs => _allPrs;

  String get weekFilter => _weekFilter;

  String get developerFilter => _developerFilter;

  String get searchTerm => _searchTerm;

  String get statusFilter => _statusFilter;

  int get currentPageIndex => _currentPageIndex;

  double get bottleneckThreshold => _bottleneckThreshold;

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  List<RepoInfo> get currentRepos => _currentRepos;

  /// PRs filtered by date range and week.
  List<PrEntity> get weekFilteredPrs {
    var prs = _filterService.filterByDateRange(_allPrs, _startDate, _endDate);
    return _filterService.filterByWeek(prs, _weekFilter);
  }

  /// PRs filtered by week + search + status (for PR lists).
  List<PrEntity> get filteredPrs => _filterService.filterPrs(
    weekFilteredPrs,
    searchTerm: _searchTerm,
    statusFilter: _statusFilter,
  );

  /// Open PRs only.
  List<PrEntity> get openPrs => filteredPrs.where((pr) => pr.isOpen).toList();

  // ─── Computed Analytics ──────────────────────────────────
  KpiEntity get kpis => _kpiService.calculateKpis(
    weekFilteredPrs,
    developerFilter: _developerFilter,
  );

  SpotlightEntity get spotlightMetrics => _kpiService.calculateSpotlightMetrics(
    weekFilteredPrs,
    developerFilter: _developerFilter,
  );

  List<BottleneckEntity> get bottlenecks =>
      _bottleneckService.identifyBottlenecks(
        weekFilteredPrs,
        thresholdHours: _bottleneckThreshold,
      );

  List<LeaderboardEntry> get leaderboard =>
      _collaborationService.calculateLeaderboard(weekFilteredPrs);


  // ─── Actions ─────────────────────────────────────────────

  /// Ensure data is loaded only if the repos have changed.
  Future<void> ensureDataLoaded(List<RepoInfo> repos) async {
    if (repos.isEmpty) return;
    
    // Check if the exact same repositories are already loaded
    if (_currentRepos.length == repos.length &&
        _currentRepos.every((r1) => repos.any((r2) => r1.fullName == r2.fullName))) {
      return; // Already loaded
    }
    
    await loadData(repos: repos);
  }

  /// Load PR data for the given [repos].
  Future<void> loadData({List<RepoInfo>? repos}) async {
    final rs = repos ?? _currentRepos;

    if (rs.isEmpty) {
      debugPrint('[DashboardProvider] No repos set. Waiting for selection.');
      return;
    }

    _currentRepos = List.from(rs);
    _status = DashboardStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregatedPrs = [];
      for (final repo in rs) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        final prs = await _repository.getPullRequests(owner, repoName);
        aggregatedPrs.addAll(prs);
      }
      _allPrs = aggregatedPrs;
      _status = DashboardStatus.loaded;
    } catch (e) {
      _status = DashboardStatus.error;
      debugPrint('Error loading PR data: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_currentRepos.isEmpty) return;

    _status = DashboardStatus.loading;
    notifyListeners();

    try {
      final List<PrEntity> aggregatedPrs = [];
      for (final repo in _currentRepos) {
        final parts = repo.fullName.split('/');
        final owner = parts.isNotEmpty ? parts.first : '';
        final repoName = repo.name;
        final prs = await _repository.refresh(owner, repoName);
        aggregatedPrs.addAll(prs);
      }
      _allPrs = aggregatedPrs;
      _status = DashboardStatus.loaded;
    } catch (e) {
      _status = DashboardStatus.error;
      debugPrint('Error refreshing PR data: $e');
    }
    notifyListeners();
  }


  void setSearchTerm(String term) {
    _searchTerm = term;
    notifyListeners();
  }


  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }
}
