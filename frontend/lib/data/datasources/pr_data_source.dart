library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

abstract class PrDataSource {
  Future<List<dynamic>> fetchPrs({required String org, required String repo, String state = 'all'});
  Future<List<dynamic>> fetchOpenPrs({required String org});
}

class RemotePrDataSource implements PrDataSource {
  final http.Client client;

  RemotePrDataSource({required this.client});

  @override
  Future<List<dynamic>> fetchPrs({
    required String org,
    required String repo,
    String state = 'all',
  }) async {
    final baseUrl = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final url = Uri.parse('$baseUrl/api/metrics/$org/$repo/prs')
        .replace(queryParameters: {'state': state});

    final response = await client.get(url, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse is Map<String, dynamic>) {
        if (jsonResponse.containsKey('data') && jsonResponse['data'] is List) {
          return jsonResponse['data'] as List<dynamic>;
        } else if (jsonResponse.containsKey('prs') && jsonResponse['prs'] is List) {
          return jsonResponse['prs'] as List<dynamic>;
        }
      }
      return [];
    } else {
      throw Exception('Failed to load PRs: ${response.statusCode}');
    }
  }

  @override
  Future<List<dynamic>> fetchOpenPrs({required String org}) async {
    final baseUrl = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    final url = Uri.parse('$baseUrl/api/prs');

    final response = await client.get(url, headers: {
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse is Map<String, dynamic> && jsonResponse.containsKey('data')) {
        return jsonResponse['data'] as List<dynamic>;
      }
      return [];
    } else {
      throw Exception('Failed to load open PRs: ${response.statusCode}');
    }
  }
}
