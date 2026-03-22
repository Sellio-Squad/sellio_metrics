enum LogSeverity { info, warning, error, success }

enum LogCategory { github, googleMeet, system }

class LogEntry {
  final String id;
  final DateTime timestamp;
  final String message;
  final LogSeverity severity;
  final LogCategory category;
  final Map<String, dynamic>? metadata;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.severity,
    required this.category,
    this.metadata,
  });
}
