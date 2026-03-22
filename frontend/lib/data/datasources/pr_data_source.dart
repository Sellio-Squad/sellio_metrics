abstract class PrDataSource {
  Future<List<dynamic>> fetchOpenPrs({required String org});
}
