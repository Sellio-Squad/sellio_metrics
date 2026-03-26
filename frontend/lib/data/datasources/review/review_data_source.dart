abstract class ReviewDataSource {
  Future<Map<String, dynamic>> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  });
}
