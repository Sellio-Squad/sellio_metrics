abstract class AuthDataSource {
  Future<bool> fetchAuthStatus();
  Future<String> fetchAuthUrl();
  Future<void> logout();
}
