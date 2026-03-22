import 'package:injectable/injectable.dart';
import '../../../core/network/api_client.dart';
import '../../models/member/member_model.dart';
import 'members_data_source.dart';

@Injectable(as: MembersDataSource, env: [Environment.prod])
class MembersDataSourceImpl implements MembersDataSource {
  final ApiClient _apiClient;

  MembersDataSourceImpl(this._apiClient);

  @override
  Future<List<MemberModel>> fetchMembersStatus() async {
    return await _apiClient.get<List<MemberModel>>(
      '/api/members',
      tag: 'MembersDataSource',
      parser: (data) {
        final body = data as Map<String, dynamic>;
        final members = body['data'] as List<dynamic>? ?? 
                        body['members'] as List<dynamic>? ?? [];
        return members.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
      },
    );
  }
}
