import 'package:sellio_metrics/domain/entities/chat_message_entity.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';

abstract class AiChatDataSource {
  Future<List<RepoInfo>> getAvailableRepos();

  Future<ChatResponseDto> sendMessage({
    required String owner,
    required String repo,
    required String message,
    required String githubLogin,
    String? sessionId,
  });

  Future<void> clearSession(String sessionId);
}

class ChatResponseDto {
  final String sessionId;
  final String message;
  final List<ToolCallRecord> toolCallsMade;

  ChatResponseDto({
    required this.sessionId,
    required this.message,
    required this.toolCallsMade,
  });

  factory ChatResponseDto.fromJson(Map<String, dynamic> json) {
    return ChatResponseDto(
      sessionId: json['sessionId'] as String,
      message: json['message'] as String,
      toolCallsMade: (json['toolCallsMade'] as List<dynamic>?)
              ?.map((e) => ToolCallRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
