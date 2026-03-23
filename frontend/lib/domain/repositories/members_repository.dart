/// Domain — MembersRepository
///
/// Abstract contract for member status data.
/// Presentation layer depends ONLY on this interface — never on impl.

import 'package:sellio_metrics/domain/entities/member_status_entity.dart';

abstract class MembersRepository {
  /// Fetch server-computed member active/inactive statuses for org.
  Future<List<MemberStatusEntity>> getMembersStatus();
}
