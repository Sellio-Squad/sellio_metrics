import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';
import 'package:sellio_metrics/data/models/log/log_model.dart';

extension LogModelMapper on LogModel {
  LogEntry toEntity() {
    return LogEntry(
      id: id,
      timestamp: timestamp,
      message: message,
      severity: LogSeverity.fromString(severity),
      category: LogCategory.fromString(category),
      metadata: metadata,
    );
  }
}
