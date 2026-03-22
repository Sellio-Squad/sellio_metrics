import 'package:injectable/injectable.dart';
import '../../../core/constants/app_constants.dart';
import '../repos_data_source.dart';
import '../../models/repo_model.dart';

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
