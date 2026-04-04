abstract class IssuesDataSource {
  Future<List<dynamic>> fetchOpenIssues({required String org});
}
