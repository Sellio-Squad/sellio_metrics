import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../pr_data_source.dart';

@Injectable(as: PrDataSource, env: [Environment.prod])
class RemotePrDataSource implements PrDataSource {
  final Dio _dio;

  RemotePrDataSource(this._dio);

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    final response = await _dio.get('/api/prs', options: Options(
      headers: {
        'Accept': 'application/json',
      },
    ));

    if (response.statusCode == 200) {
      final jsonResponse = response.data;
      if (jsonResponse is Map<String, dynamic> && jsonResponse.containsKey('data')) {
        return jsonResponse['data'] as List<dynamic>;
      }
      return [];
    } else {
      throw Exception('Failed to load open PRs: ${response.statusCode}');
    }
  }
}
