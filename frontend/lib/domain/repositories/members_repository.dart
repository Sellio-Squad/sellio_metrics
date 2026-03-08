/// Domain — MembersRepository
///
/// Abstract contract for member status data.
/// Presentation layer depends ONLY on this interface — never on impl.
library;

import '../entities/member_status_entity.dart';

abstract class MembersRepository {
  /// Fetch server-computed member active/inactive statuses for [owner]/[repo].
  Future<List<MemberStatusEntity>> getMembersStatus(String owner, String repo);
}
