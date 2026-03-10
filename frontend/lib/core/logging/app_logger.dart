import 'package:flutter/foundation.dart';

/// App-wide logger interface for centralized logging.
abstract class AppLogger {
  /// Logs network requests and responses.
  void network(String tag, String method, Uri url);

  /// Logs errors with optional stack trace.
  void error(String tag, Object error, [StackTrace? stack]);

  /// Logs informational messages.
  void info(String tag, String message);

  /// Logs debug-level messages.
  void debug(String tag, String message);
}

/// A concrete implementation of [AppLogger] that prints to the console.
class ConsoleAppLogger implements AppLogger {
  @override
  void network(String tag, String method, Uri url) {
    debugPrint('🌐 [$tag] $method $url');
  }

  @override
  void error(String tag, Object error, [StackTrace? stack]) {
    debugPrint('❌ [$tag] Error: $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }

  @override
  void info(String tag, String message) {
    debugPrint('ℹ️ [$tag] $message');
  }

  @override
  void debug(String tag, String message) {
    debugPrint('🔍 [$tag] $message');
  }
}
