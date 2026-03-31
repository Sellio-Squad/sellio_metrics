import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/log_entry_entity.dart';
import 'package:sellio_metrics/domain/repositories/logs_repository.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

@injectable
class LogsProvider extends ChangeNotifier {
  final LogsRepository _repository;

  bool _isLoading = false;
  String? _error;
  List<LogEntry> _logs = [];

  LogsProvider(this._repository);

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LogEntry> get logs => _logs;

  Future<void> fetchLogs({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final backendLogs = await _repository.getLogs(limit: limit);
      final frontendLogs = appLogger.logs;
      
      _logs = [...backendLogs, ...frontendLogs];
      _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearLogs() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.clearLogs();
      appLogger.clearLogs();
      
      _logs = [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
