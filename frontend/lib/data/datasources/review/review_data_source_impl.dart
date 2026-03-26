import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/review/review_data_source.dart';

@Injectable(as: ReviewDataSource, env: [Environment.prod])
class ReviewDataSourceImpl implements ReviewDataSource {
  final ApiClient _apiClient;

  ReviewDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> reviewPr({
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    return await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reviewPr,
      tag: 'review-pr',
      data: {
        'owner': owner,
        'repo': repo,
        'prNumber': prNumber,
      },
      parser: (data) => data as Map<String, dynamic>,
    );
  }
}
