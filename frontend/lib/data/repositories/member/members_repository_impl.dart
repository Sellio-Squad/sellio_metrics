import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/member_status_entity.dart';
import 'package:sellio_metrics/domain/repositories/members_repository.dart';
import 'package:sellio_metrics/data/datasources/member/members_data_source.dart';
import 'package:sellio_metrics/data/mappers/member/member_mappers.dart';

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
