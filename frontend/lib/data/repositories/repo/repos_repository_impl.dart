import 'package:injectable/injectable.dart';
import '../../../../domain/entities/repo_info.dart';
import '../../../../domain/repositories/repos_repository.dart';
import '../../datasources/repo/repos_data_source.dart';
import '../../mappers/repo/repo_mappers.dart';

@LazySingleton(as: ReposRepository)
class ReposRepositoryImpl implements ReposRepository {
  final ReposDataSource _dataSource;

  ReposRepositoryImpl(this._dataSource);

  @override
  Future<List<RepoInfo>> getRepositories() async {
    final models = await _dataSource.fetchRepositories();
    return models.map((m) => m.toEntity()).toList();
  }
}
