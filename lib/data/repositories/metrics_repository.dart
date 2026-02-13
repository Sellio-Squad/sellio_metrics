/// Sellio Metrics — Metrics Repository
///
/// Mediates between data sources and domain layer.
/// Applies the Repository pattern for clean separation of concerns.
library;

import '../datasources/local_data_source.dart';
import '../models/pr_model.dart';

/// Repository interface for metrics data operations.
abstract class MetricsRepository {
  Future<List<PrModel>> getPullRequests();
}

/// Default repository implementation using a [MetricsDataSource].
class MetricsRepositoryImpl implements MetricsRepository {
  final MetricsDataSource _dataSource;

  /// Cached data to avoid reloading from assets on every call.
  List<PrModel>? _cache;

  MetricsRepositoryImpl({MetricsDataSource? dataSource})
      : _dataSource = dataSource ?? LocalDataSource();

  @override
  Future<List<PrModel>> getPullRequests() async {
    _cache ??= await _dataSource.fetchPullRequests();
    return _cache!;
  }

  /// Invalidate cache (useful when swapping data sources or refreshing).
  void invalidateCache() => _cache = null;
}
