/// Data — MembersRepositoryImpl
///
/// Implements the domain MembersRepository interface.
/// Depends on MembersDataSource (interface, not concrete).
/// Maps raw JSON to domain MemberStatusEntity.
library;

import 'package:injectable/injectable.dart';
import '../../domain/entities/member_status_entity.dart';
import '../../domain/repositories/members_repository.dart';
import '../datasources/members_data_source.dart';

@LazySingleton(as: MembersRepository)
class MembersRepositoryImpl implements MembersRepository {
  final MembersDataSource _dataSource;

  MembersRepositoryImpl(this._dataSource);

  @override
  Future<List<MemberStatusEntity>> getMembersStatus() async {
    final raw = await _dataSource.fetchMembersStatus();
    return raw.map(_toEntity).toList();
  }

  MemberStatusEntity _toEntity(dynamic json) {
    final m = json as Map<String, dynamic>;
    return MemberStatusEntity(
      developer: m['developer'] as String? ?? 'Unknown',
      avatarUrl: m['avatarUrl'] as String?,
      isActive: m['isActive'] as bool? ?? false,
      lastActiveDate: m['lastActiveDate'] != null
          ? DateTime.tryParse(m['lastActiveDate'] as String)
          : null,
    );
  }
}
