import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/data/models/member/member_model.dart';
import 'package:sellio_metrics/data/datasources/member/members_data_source.dart';

@Injectable(as: MembersDataSource, env: [Environment.prod])
class MembersDataSourceImpl implements MembersDataSource {
  final ApiClient _apiClient;

  MembersDataSourceImpl(this._apiClient);

  @override
  Future<List<MemberModel>> fetchMembersStatus() async {
    return await _apiClient.get<List<MemberModel>>(
      ApiEndpoints.members,
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
