import 'package:sellio_metrics/domain/entities/review_entity.dart';

abstract class ReviewRepository {
  Future<ReviewEntity> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  });

  /// Run (or reuse cached) review and post it as a comment on the GitHub PR.
  Future<ReviewEntity> postReviewComment({
    required String owner,
    required String repo,
    required int prNumber,
  });

  /// Single request → { repos: [...], prs: [...] }
  Future<Map<String, dynamic>> fetchMeta();
}
