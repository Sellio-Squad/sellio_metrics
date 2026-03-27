import 'package:flutter/foundation.dart';
import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void _addLog(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
  }

  void network(String tag, String method, Uri url) {
    debugPrint('🌐 [$tag] $method $url');
    _addLog(LogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: '[$tag] $method $url',
      severity: LogSeverity.info,
      category: LogCategory.frontend,
    ));
  }

  void error(String tag, Object error, [StackTrace? stack]) {
    debugPrint('❌ [$tag] Error: $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
    _addLog(LogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: '[$tag] Error: $error',
      severity: LogSeverity.error,
      category: LogCategory.frontend,
      metadata: stack != null ? {'stackTrace': stack.toString()} : null,
    ));
  }

  void info(String tag, String message) {
    debugPrint('ℹ️ [$tag] $message');
    _addLog(LogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: '[$tag] $message',
      severity: LogSeverity.info,
      category: LogCategory.frontend,
    ));
  }

  void debug(String tag, String message) {
    debugPrint('🔍 [$tag] $message');
    _addLog(LogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: '[$tag] $message',
      severity: LogSeverity.info,
      category: LogCategory.frontend,
    ));
  }
}

final appLogger = AppLogger();
