library;

import '../entities/pr_entity.dart';

abstract class PrRepository {
  Future<List<PrEntity>> fetchPrs({
    required String org,
    required String repo,
    String state = 'all',
  });

  Future<List<PrEntity>> fetchOpenPrs({required String org});
}
