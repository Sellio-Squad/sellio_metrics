import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_auth_data_source.dart';

@Injectable(as: MeetAuthDataSource, env: [Environment.dev])
class FakeMeetAuthDataSource implements MeetAuthDataSource {
  @override
  Future<bool> fetchAuthStatus() async => true;

  @override
  Future<String> fetchAuthUrl() async => 'https://fake-auth-url.com';

  @override
  Future<void> logout() async {}
}
