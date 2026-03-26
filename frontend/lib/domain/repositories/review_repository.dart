import 'package:sellio_metrics/domain/entities/review_entity.dart';

abstract class ReviewRepository {
  Future<ReviewEntity> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  });
}
