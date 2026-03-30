
class LogModel {
  final String id;
  final DateTime timestamp;
  final String message;
  final String severity;
  final String category;
  final Map<String, dynamic>? metadata;

  const LogModel({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.severity,
    required this.category,
    this.metadata,
  });

  factory LogModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedMetadata;
    if (json['metadata'] != null && json['metadata'] is Map) {
      parsedMetadata = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return LogModel(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      message: json['message']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      category: json['category']?.toString() ?? 'system',
      metadata: parsedMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'severity': severity,
      'category': category,
      'metadata': metadata,
    };
  }
}
