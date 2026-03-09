import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class HealthDataSource {
  Future<Map<String, dynamic>?> fetchHealthStatus();
  Future<Map<String, dynamic>?> fetchCacheQuota();
}

class RemoteHealthDataSource implements HealthDataSource {
  final String baseUrl;
  final http.Client _client;

  RemoteHealthDataSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>?> fetchHealthStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchCacheQuota() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/debug/cache-quota'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
