/// Sellio Metrics — Domain Repository Interface
///
/// Abstract contract for metrics data operations.
/// Data layer provides the implementation; domain and presentation
/// depend only on this abstraction.
library;

import '../entities/pr_entity.dart';
import '../entities/leaderboard_entry.dart';

/// Lightweight repository info for the settings UI.
class RepoInfo {
  final String name;
  final String fullName;
  final String? description;

  const RepoInfo({
    required this.name,
    required this.fullName,
    this.description,
  });
}

/// Repository interface for pull request metrics data.
abstract class MetricsRepository {
  /// Fetch all pull requests for the given [owner]/[repo].
  Future<List<PrEntity>> getPullRequests(String owner, String repo);

  /// Force-refresh the cache and re-fetch from source.
  Future<List<PrEntity>> refresh(String owner, String repo);

  /// Fetch the list of available repositories for the org.
  Future<List<RepoInfo>> getRepositories();

  /// Calculate leaderboard remotely on the backend based on selected PRs.
  Future<List<LeaderboardEntry>> calculateLeaderboard(List<PrEntity> prs);
}
