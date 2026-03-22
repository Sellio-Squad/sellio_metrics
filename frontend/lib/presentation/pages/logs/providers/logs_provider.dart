import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../../../domain/entities/log_entry_entity.dart';
import '../../../../domain/repositories/logs_repository.dart';

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
      _logs = await _repository.getLogs(limit: limit);
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
