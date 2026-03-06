import 'package:flutter/foundation.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/metrics_repository.dart';

class LeaderboardProvider extends ChangeNotifier {
  final MetricsRepository _repository;

  LeaderboardProvider({required MetricsRepository repository})
    : _repository = repository;

  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = false;

  List<LeaderboardEntry> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;

  Future<void> fetchLeaderboard(List<PrEntity> sourcePrs) async {
    if (sourcePrs.isEmpty) {
      _leaderboard = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _leaderboard = await _repository.calculateLeaderboard(sourcePrs);
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      _leaderboard = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
