/// Presentation — LeaderboardProvider
///
/// Manages leaderboard filter state: date range (since/until) and
/// selected repo IDs (multi-select). Quick preset labels are
/// converted to ISO dates client-side before sending to the API.

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import 'package:sellio_metrics/domain/entities/leaderboard_entry.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/domain/repositories/leaderboard_repository.dart';
import 'package:sellio_metrics/domain/repositories/repos_repository.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

// ─── Quick preset helpers ─────────────────────────────────────────────────────

enum LeaderboardPreset { allTime, thisMonth, thisWeek, custom }

extension LeaderboardPresetX on LeaderboardPreset {
  String get label {
    switch (this) {
      case LeaderboardPreset.allTime:    return 'All Time';
      case LeaderboardPreset.thisMonth:  return 'This Month';
      case LeaderboardPreset.thisWeek:   return 'This Week';
      case LeaderboardPreset.custom:     return 'Custom';
    }
  }

  /// Converts the preset to an ISO-8601 since string (null = no start boundary).
  String? toSince() {
    final now = DateTime.now().toUtc();
    switch (this) {
      case LeaderboardPreset.allTime:
        return null;
      case LeaderboardPreset.thisMonth:
        return DateTime.utc(now.year, now.month, 1).toIso8601String();
      case LeaderboardPreset.thisWeek:
        // Monday-based week
        final daysBack = now.weekday - 1; // weekday: Mon=1 .. Sun=7
        final monday = now.subtract(Duration(days: daysBack));
        return DateTime.utc(monday.year, monday.month, monday.day).toIso8601String();
      case LeaderboardPreset.custom:
        return null; // handled separately via customStart
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

@injectable
class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardRepository _repository;
  final ReposRepository _reposRepository;

  LeaderboardProvider(this._repository, this._reposRepository);

  // ── Leaderboard data ──
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = false;
  String? _error;

  // ── Available repos (from D1 /synced) ──
  List<RepoInfo> _availableRepos = [];
  bool _reposLoading = false;

  // ── Filter state ──
  LeaderboardPreset _preset = LeaderboardPreset.allTime;
  DateTime? _customStart;
  DateTime? _customEnd;
  Set<int> _selectedRepoIds = {}; // empty = all repos

  // ── Getters ──
  List<LeaderboardEntry> get leaderboard    => _leaderboard;
  bool                   get isLoading      => _isLoading;
  String?                get error          => _error;
  List<RepoInfo>         get availableRepos => _availableRepos;
  bool                   get reposLoading   => _reposLoading;
  LeaderboardPreset      get preset         => _preset;
  DateTime?              get customStart    => _customStart;
  DateTime?              get customEnd      => _customEnd;
  Set<int>               get selectedRepoIds => _selectedRepoIds;

  DateTime? get effectiveStart {
    if (_preset == LeaderboardPreset.custom) return _customStart;
    final iso = _preset.toSince();
    return iso == null ? null : DateTime.parse(iso).toLocal();
  }

  DateTime? get effectiveEnd {
    if (_preset == LeaderboardPreset.custom) return _customEnd;
    if (_preset == LeaderboardPreset.allTime) return null;
    return DateTime.now();
  }

  bool get hasActiveFilters =>
      _preset != LeaderboardPreset.allTime || _selectedRepoIds.isNotEmpty;

  // ─── Filter setters ──────────────────────────────────────────────────────

  void setPreset(LeaderboardPreset preset) {
    if (_preset == preset) return;
    _preset = preset;
    if (preset != LeaderboardPreset.custom) {
      _customStart = null;
      _customEnd   = null;
    }
    notifyListeners();
    fetchLeaderboard();
  }

  void setCustomDateRange(DateTime? start, DateTime? end) {
    _customStart = start;
    _customEnd   = end;
    _preset      = LeaderboardPreset.custom;
    notifyListeners();
    fetchLeaderboard();
  }

  void toggleRepo(int repoId) {
    final updated = Set<int>.from(_selectedRepoIds);
    if (updated.contains(repoId)) {
      updated.remove(repoId);
    } else {
      updated.add(repoId);
    }
    _selectedRepoIds = updated;
    notifyListeners();
    fetchLeaderboard();
  }

  void clearRepoFilter() {
    if (_selectedRepoIds.isEmpty) return;
    _selectedRepoIds = {};
    notifyListeners();
    fetchLeaderboard();
  }

  void clearAllFilters() {
    _preset          = LeaderboardPreset.allTime;
    _customStart     = null;
    _customEnd       = null;
    _selectedRepoIds = {};
    notifyListeners();
    fetchLeaderboard();
  }

  // ─── Data loading ────────────────────────────────────────────────────────

  /// Load synced repos for the repo filter dropdown.
  Future<void> loadAvailableRepos() async {
    if (_availableRepos.isNotEmpty) return; // already loaded
    _reposLoading = true;
    notifyListeners();
    try {
      _availableRepos = await _reposRepository.getRepositories();
    } catch (e, stack) {
      appLogger.error('LeaderboardProvider', 'Failed to load repos: $e', stack);
    } finally {
      _reposLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final since = _effectiveSince();
      final until = _effectiveUntil();
      final repoIds = _selectedRepoIds.isEmpty ? null : _selectedRepoIds.toList();

      final entries = await _repository.getLeaderboard(
        since:   since,
        until:   until,
        repoIds: repoIds,
      );
      _leaderboard = entries..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } catch (e, stack) {
      appLogger.error('LeaderboardProvider', 'Error: $e', stack);
      _error       = e.toString();
      _leaderboard = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  String? _effectiveSince() {
    if (_preset == LeaderboardPreset.custom) {
      return _customStart?.toUtc().toIso8601String();
    }
    return _preset.toSince();
  }

  String? _effectiveUntil() {
    if (_preset == LeaderboardPreset.custom) {
      return _customEnd?.toUtc().toIso8601String();
    }
    return null;
  }
}
