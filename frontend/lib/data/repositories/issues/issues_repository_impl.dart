import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/issue_entity.dart';
import 'package:sellio_metrics/domain/repositories/issues_repository.dart';
import 'package:sellio_metrics/data/datasources/issues/issues_data_source.dart';

@LazySingleton(as: IssuesRepository)
class IssuesRepositoryImpl implements IssuesRepository {
  final IssuesDataSource _dataSource;

  const IssuesRepositoryImpl(this._dataSource);

  @override
  Future<List<IssueEntity>> fetchOpenIssues({required String org}) async {
    final rawData = await _dataSource.fetchOpenIssues(org: org);
    return rawData
        .map((json) {
          try {
            return IssueEntity.fromJson(json as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<IssueEntity>()
        .toList();
  }
}
