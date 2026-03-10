/// Presentation — LeaderboardProvider
///
/// Depends on [LeaderboardRepository] (interface, not concrete).
/// Fetches server-computed leaderboard for selected repos and merges
/// entries across repos by summing scores for each developer.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/logging/app_logger.dart';

class LeaderboardProvider extends ChangeNotifier {
  /// Depends on INTERFACE — satisfies Dependency Inversion Principle.
  final LeaderboardRepository _repository;

  LeaderboardProvider({required LeaderboardRepository repository})
    : _repository = repository;

  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = false;
  String? _error;

  List<LeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch leaderboard for [repoFullNames] (e.g. ["Sellio-Squad/sellio_mobile"]).
  /// Entries are merged across repos (scores summed per developer).
  Future<void> fetchLeaderboard(List<String> repoFullNames) async {
    if (repoFullNames.isEmpty) {
      _leaderboard = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final merged = <String, LeaderboardEntry>{};

      for (final fullName in repoFullNames) {
        final parts = fullName.split('/');
        if (parts.length != 2) continue;

        final entries = await _repository.getLeaderboard(parts[0], parts[1]);

        for (final e in entries) {
          final existing = merged[e.developer];
          merged[e.developer] = existing == null
              ? e
              : LeaderboardEntry(
                  developer: e.developer,
                  avatarUrl: e.avatarUrl ?? existing.avatarUrl,
                  prsCreated: existing.prsCreated + e.prsCreated,
                  prsMerged: existing.prsMerged + e.prsMerged,
                  reviewsGiven: existing.reviewsGiven + e.reviewsGiven,
                  commentsGiven: existing.commentsGiven + e.commentsGiven,
                  additions: existing.additions + e.additions,
                  deletions: existing.deletions + e.deletions,
                  totalScore: existing.totalScore + e.totalScore,
                );
        }
      }

      _leaderboard = merged.values.toList()
        ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } catch (e, stack) {
      sl.get<AppLogger>().error('LeaderboardProvider', 'Error: $e', stack);
      _error = e.toString();
      _leaderboard = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
