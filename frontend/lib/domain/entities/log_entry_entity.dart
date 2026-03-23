enum LogSeverity {
  info,
  warning,
  error,
  success;

  static LogSeverity fromString(String? value) =>
      _lookup[value?.toLowerCase()] ?? LogSeverity.info;

  static final _lookup = {
    for (final v in values) v.name: v,
  };
}

enum LogCategory {
  github,
  googleMeet,
  system;

  static LogCategory fromString(String? value) =>
      _lookup[value?.toLowerCase()] ?? LogCategory.system;

  static final _lookup = {
    for (final v in values) v.name.toLowerCase(): v,
  };
}

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
