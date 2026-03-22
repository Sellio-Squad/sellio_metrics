import 'package:injectable/injectable.dart';
import '../../domain/entities/member_status_entity.dart';
import '../../domain/repositories/members_repository.dart';
import '../datasources/members_data_source.dart';
import '../mappers/member_mappers.dart';

@LazySingleton(as: MembersRepository)
class MembersRepositoryImpl implements MembersRepository {
  final MembersDataSource _dataSource;

  MembersRepositoryImpl(this._dataSource);

  @override
  Future<List<MemberStatusEntity>> getMembersStatus() async {
    final models = await _dataSource.fetchMembersStatus();
    return models.map((m) => m.toEntity()).toList();
  }
}
