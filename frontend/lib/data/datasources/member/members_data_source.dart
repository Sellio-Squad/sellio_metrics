import 'package:sellio_metrics/data/models/member/member_model.dart';

abstract class MembersDataSource {
  Future<List<MemberModel>> fetchMembersStatus();
}
