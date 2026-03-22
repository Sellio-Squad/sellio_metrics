import '../../domain/entities/log_entry_entity.dart';
import '../models/log_model.dart';

extension LogModelMapper on LogModel {
  LogEntry toEntity() {
    return LogEntry(
      id: id,
      timestamp: timestamp,
      message: message,
      severity: _mapSeverity(severity),
      category: _mapCategory(category),
      metadata: metadata,
    );
  }

  LogSeverity _mapSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'info':
        return LogSeverity.info;
      case 'warning':
        return LogSeverity.warning;
      case 'error':
        return LogSeverity.error;
      case 'success':
        return LogSeverity.success;
      default:
        return LogSeverity.info;
    }
  }

  LogCategory _mapCategory(String category) {
    switch (category.toLowerCase()) {
      case 'github':
        return LogCategory.github;
      case 'googlemeet':
        return LogCategory.googleMeet;
      case 'system':
        return LogCategory.system;
      default:
        return LogCategory.system;
    }
  }
}
