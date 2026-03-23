import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/data/models/repo/repo_model.dart';
import 'package:sellio_metrics/data/datasources/repo/repos_data_source.dart';


@Injectable(as: ReposDataSource, env: [Environment.dev])
class FakeReposDataSource implements ReposDataSource {
  @override
  Future<List<RepoModel>> fetchRepositories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      RepoModel(
        name: ApiConfig.defaultRepo,
        fullName: '${ApiConfig.defaultOrg}/${ApiConfig.defaultRepo}',
        description: 'Fake repo for local metrics preview',
      ),
    ];
  }
}
