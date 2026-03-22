import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../../../core/logging/app_logger.dart';
import '../members_data_source.dart';
import '../../models/member_model.dart';

@Injectable(as: MembersDataSource, env: [Environment.prod])
class RemoteMembersDataSource implements MembersDataSource {
  final Dio _dio;

  RemoteMembersDataSource(this._dio);

  @override
  Future<List<MemberModel>> fetchMembersStatus() async {
    final url = '/api/members';
    appLogger.network('MembersDataSource', 'GET', Uri.parse(_dio.options.baseUrl + url));

    final response = await _dio.get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'Members fetch failed: ${response.statusCode} ${response.data}',
      );
    }

    final body = response.data as Map<String, dynamic>;
    final members = body['data'] as List<dynamic>? ?? body['members'] as List<dynamic>? ?? [];
    return members.map((json) => MemberModel.fromJson(json as Map<String, dynamic>)).toList();
  }
}
