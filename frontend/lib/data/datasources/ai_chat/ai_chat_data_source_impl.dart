import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/ai_chat/ai_chat_data_source.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';

@LazySingleton(as: AiChatDataSource)
class AiChatDataSourceImpl implements AiChatDataSource {
  final ApiClient _apiClient;

  AiChatDataSourceImpl(this._apiClient);

  @override
  Future<List<RepoInfo>> getAvailableRepos() async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.aiChatRepos,
      tag: 'AiChatDataSource.getAvailableRepos',
    );
    final reposList = (res['repos'] as List<dynamic>?) ?? [];
    return reposList
        .map((r) => RepoInfo.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChatResponseDto> sendMessage({
    required String owner,
    required String repo,
    required String message,
    required String githubLogin,
    String? sessionId,
  }) async {
    final res = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.aiChatMessage,
      tag: 'AiChatDataSource.sendMessage',
      data: {
        'owner': owner,
        'repo': repo,
        'message': message,
        'githubLogin': githubLogin,
        if (sessionId != null) 'sessionId': sessionId,
      },
    );
    return ChatResponseDto.fromJson(res);
  }

  @override
  Future<void> clearSession(String sessionId) async {
    await _apiClient.delete<void>(
      ApiEndpoints.aiChatSession(sessionId),
      tag: 'AiChatDataSource.clearSession',
    );
  }
}
