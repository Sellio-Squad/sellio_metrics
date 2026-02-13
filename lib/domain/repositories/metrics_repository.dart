/// Sellio Metrics — Domain Repository Interface
///
/// Abstract contract for metrics data operations.
/// Data layer provides the implementation; domain and presentation
/// depend only on this abstraction.
library;

import '../entities/pr_entity.dart';

/// Repository interface for pull request metrics data.
abstract class MetricsRepository {
  /// Fetch all pull requests.
  Future<List<PrEntity>> getPullRequests();

  /// Force-refresh the cache and re-fetch from source.
  Future<List<PrEntity>> refresh();
}
