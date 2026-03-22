import 'package:injectable/injectable.dart';
import '../auth/auth_data_source.dart';

@Injectable(as: AuthDataSource, env: [Environment.dev])
class FakeAuthDataSource implements AuthDataSource {
  @override
  Future<bool> fetchAuthStatus() async => true;

  @override
  Future<String> fetchAuthUrl() async => 'https://fake-auth-url.com';

  @override
  Future<void> logout() async {}
}
