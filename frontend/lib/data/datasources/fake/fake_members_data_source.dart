import 'package:injectable/injectable.dart';
import '../members_data_source.dart';
import '../../models/member_model.dart';

@Injectable(as: MembersDataSource, env: [Environment.dev])
class FakeMembersDataSource implements MembersDataSource {
  @override
  Future<List<MemberModel>> fetchMembersStatus() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final json = [
      {
        'developer': 'alice',
        'avatarUrl': 'https://avatars.githubusercontent.com/u/1?v=4',
        'isActive': true,
        'lastActiveDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'developer': 'bob',
        'avatarUrl': 'https://avatars.githubusercontent.com/u/2?v=4',
        'isActive': true,
        'lastActiveDate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
    return json.map((e) => MemberModel.fromJson(e)).toList();
  }
}
