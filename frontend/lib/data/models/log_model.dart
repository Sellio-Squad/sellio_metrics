
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
    return LogModel(
      id: json['id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
      category: json['category'] as String? ?? 'system',
      metadata: json['metadata'] as Map<String, dynamic>?,
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
