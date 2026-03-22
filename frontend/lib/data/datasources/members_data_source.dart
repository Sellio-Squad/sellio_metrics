import '../models/member_model.dart';

abstract class MembersDataSource {
  Future<List<MemberModel>> fetchMembersStatus();
}
