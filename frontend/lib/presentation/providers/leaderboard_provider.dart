/// Presentation — LeaderboardProvider
///
/// Depends on [LeaderboardRepository] (interface, not concrete).
/// Fetches server-computed leaderboard for selected repos and merges
/// entries across repos by summing scores for each developer.
library;

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../../core/logging/app_logger.dart';

@injectable
class LeaderboardProvider extends ChangeNotifier {
  /// Depends on INTERFACE — satisfies Dependency Inversion Principle.
  final LeaderboardRepository _repository;

  LeaderboardProvider(this._repository);

  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = false;
  String? _error;

  List<LeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch global leaderboard across all repositories.
  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final entries = await _repository.getLeaderboard();
      _leaderboard = entries..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } catch (e, stack) {
      appLogger.error('LeaderboardProvider', 'Error: $e', stack);
      _error = e.toString();
      _leaderboard = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
