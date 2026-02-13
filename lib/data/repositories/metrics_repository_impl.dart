/// Sellio Metrics — Repository Implementation
///
/// Concrete repository that reads from a [MetricsDataSource]
/// and maps data models to domain entities.
library;

import '../datasources/local_data_source.dart';
import '../mappers/pr_mappers.dart';

import '../../domain/entities/pr_entity.dart';
import '../../domain/repositories/metrics_repository.dart';

class MetricsRepositoryImpl implements MetricsRepository {
  final MetricsDataSource _dataSource;

  /// Cached entities to avoid reloading from assets on every call.
  List<PrEntity>? _cache;

  MetricsRepositoryImpl({required MetricsDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<PrEntity>> getPullRequests() async {
    _cache ??= await _fetchAndMap();
    return _cache!;
  }

  @override
  Future<List<PrEntity>> refresh() async {
    _cache = null;
    return getPullRequests();
  }

  Future<List<PrEntity>> _fetchAndMap() async {
    final models = await _dataSource.fetchPullRequests();
    return models.map((m) => m.toEntity()).toList();
  }
}
