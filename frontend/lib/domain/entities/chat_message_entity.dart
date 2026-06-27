enum MessageRole { user, assistant, toolResult }

class ToolCallRecord {
  final String name;
  final dynamic args;
  final dynamic result;

  const ToolCallRecord({
    required this.name,
    required this.args,
    this.result,
  });

  factory ToolCallRecord.fromJson(Map<String, dynamic> json) {
    return ToolCallRecord(
      name: json['name'] as String,
      args: json['args'],
      result: json['result'],
    );
  }
}

class ChatMessageEntity {
  final MessageRole role;
  final String content;
  final String? toolName;
  final dynamic toolArgs;
  final dynamic toolResult;
  final DateTime timestamp;
  final List<ToolCallRecord> toolCallsMade;

  const ChatMessageEntity({
    required this.role,
    required this.content,
    this.toolName,
    this.toolArgs,
    this.toolResult,
    required this.timestamp,
    this.toolCallsMade = const [],
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) {
    return ChatMessageEntity(
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      toolName: json['toolName'] as String?,
      toolArgs: json['toolArgs'],
      toolResult: json['toolResult'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      toolCallsMade: (json['toolCallsMade'] as List<dynamic>?)
              ?.map((e) => ToolCallRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
