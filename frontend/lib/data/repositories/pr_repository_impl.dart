library;

import '../../domain/entities/pr_entity.dart';
import '../../domain/repositories/pr_repository.dart';
import '../datasources/pr_data_source.dart';

class PrRepositoryImpl implements PrRepository {
  final PrDataSource remoteDataSource;

  const PrRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<PrEntity>> fetchPrs({
    required String org,
    required String repo,
    String state = 'all',
  }) async {
    final rawData = await remoteDataSource.fetchPrs(org: org, repo: repo, state: state);
    return rawData
        .map((json) {
      try {
        return PrEntity.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        return null; // Skip invalid entries
      }
    })
        .whereType<PrEntity>()
        .toList();
  }
}
