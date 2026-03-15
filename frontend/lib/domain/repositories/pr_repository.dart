library;

import '../entities/pr_entity.dart';

abstract class PrRepository {
  Future<List<PrEntity>> fetchOpenPrs({required String org});
}
