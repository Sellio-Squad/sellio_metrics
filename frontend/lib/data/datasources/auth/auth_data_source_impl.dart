import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import 'auth_data_source.dart';

@Injectable(as: AuthDataSource, env: [Environment.prod])
class AuthDataSourceImpl implements AuthDataSource {
  final ApiClient _apiClient;

  AuthDataSourceImpl(this._apiClient);

  @override
  Future<bool> fetchAuthStatus() async {
    final data = await _apiClient.get<Map<String, dynamic>>('/api/meetings/auth/status');
    return data['authenticated'] as bool? ?? false;
  }

  @override
  Future<String> fetchAuthUrl() async {
    final data = await _apiClient.get<Map<String, dynamic>>('/api/meetings/auth/url');
    return data['url'] as String;
  }

  @override
  Future<void> logout() async {
    await _apiClient.post('/api/auth/logout');
  }
}
