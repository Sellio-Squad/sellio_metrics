/// Google Meet OAuth — NOT app-wide auth.
abstract class MeetAuthDataSource {
  Future<bool> fetchAuthStatus();
  Future<String> fetchAuthUrl();
  Future<void> logout();
}
