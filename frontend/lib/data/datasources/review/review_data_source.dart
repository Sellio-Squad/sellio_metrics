abstract class ReviewDataSource {
  Future<Map<String, dynamic>> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  });

  /// Run (or reuse cached) review and post it as a comment on the GitHub PR.
  Future<Map<String, dynamic>> postReviewComment({
    required String owner,
    required String repo,
    required int prNumber,
  });

  /// One request returning { repos: [...], prs: [...] } for the review dropdowns
  Future<Map<String, dynamic>> fetchMeta();
}
