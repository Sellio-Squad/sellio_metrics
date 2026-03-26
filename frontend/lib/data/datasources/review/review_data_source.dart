abstract class ReviewDataSource {
  Future<Map<String, dynamic>> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  });

  /// One request returning { repos: [...], prs: [...] } for the review dropdowns
  Future<Map<String, dynamic>> fetchMeta();
}
