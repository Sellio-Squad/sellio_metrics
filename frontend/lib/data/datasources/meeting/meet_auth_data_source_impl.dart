import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_auth_data_source.dart';

@Injectable(as: MeetAuthDataSource, env: [Environment.prod])
class MeetAuthDataSourceImpl implements MeetAuthDataSource {
  final ApiClient _apiClient;

  MeetAuthDataSourceImpl(this._apiClient);

  @override
  Future<bool> fetchAuthStatus() async {
    final data = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.meetAuthStatus);
    return data['authenticated'] as bool? ?? false;
  }

  @override
  Future<String> fetchAuthUrl() async {
    final data = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.meetAuthUrl);
    return data['url'] as String;
  }

  @override
  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.meetAuthLogout);
  }
}
