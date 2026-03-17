import 'package:flutter/foundation.dart';

/// App-wide logger for centralized logging.
class AppLogger {
  // Singleton instance
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal();

  /// Logs network requests and responses.
  void network(String tag, String method, Uri url) {
    debugPrint('🌐 [$tag] $method $url');
  }

  /// Logs errors with optional stack trace.
  void error(String tag, Object error, [StackTrace? stack]) {
    debugPrint('❌ [$tag] Error: $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }

  /// Logs informational messages.
  void info(String tag, String message) {
    debugPrint('ℹ️ [$tag] $message');
  }

  /// Logs debug-level messages.
  void debug(String tag, String message) {
    debugPrint('🔍 [$tag] $message');
  }
}

final appLogger = AppLogger();
