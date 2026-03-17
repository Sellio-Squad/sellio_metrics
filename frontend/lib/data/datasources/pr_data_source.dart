library;

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../core/constants/app_constants.dart';

abstract class PrDataSource {
  Future<List<dynamic>> fetchOpenPrs({required String org});
}

@Injectable(as: PrDataSource, env: [Environment.prod])
class RemotePrDataSource implements PrDataSource {
  final Dio _dio;

  RemotePrDataSource(this._dio);

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    final baseUrl = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final url = '$baseUrl/api/prs';

    final response = await _dio.get(url, options: Options(
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
