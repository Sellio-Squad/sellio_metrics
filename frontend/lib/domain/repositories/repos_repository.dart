/// Domain — ReposRepository
///
/// Abstract contract for fetching available GitHub repositories.
/// Split from MetricsRepository because loading repos is a separate concern.
library;

abstract class ReposRepository {
  /// Fetch available repos for the configured organisation.
  Future<List<RepoInfo>> getRepositories();
}

/// Lightweight repository info used by the settings/selector UI.
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
