import 'package:flutter/foundation.dart';
import '../../data/datasources/fake/fake_logs.dart';
import '../../data/datasources/logs_data_source.dart';

class LogsProvider extends ChangeNotifier {
  final LogsDataSource _dataSource;

  bool _isLoading = false;
  String? _error;
  List<LogEntry> _logs = [];

  LogsProvider({required LogsDataSource dataSource}) : _dataSource = dataSource;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LogEntry> get logs => _logs;

  Future<void> fetchLogs({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logs = await _dataSource.fetchLogs(limit: limit);
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
