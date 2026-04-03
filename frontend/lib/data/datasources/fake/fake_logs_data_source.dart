import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/models/log/log_model.dart';
import 'package:sellio_metrics/data/datasources/log/logs_data_source.dart';

@Injectable(as: LogsDataSource, env: [Environment.dev])
class FakeLogsDataSource implements LogsDataSource {
  @override
  Future<List<LogModel>> fetchLogs({int limit = 50}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    final logs = [
      {
        'id': 'log_1',
        'timestamp': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        'message': 'GitHub PR cache invalidated for sellio_mobile',
        'severity': 'info',
        'category': 'github',
        'metadata': {'repo': 'sellio_mobile', 'trigger': 'webhook:pull_request'},
      },
      {
        'id': 'log_2',
        'timestamp': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'message': 'Google Meet attendees synchronisation completed',
        'severity': 'success',
        'category': 'googleMeet',
        'metadata': {'meetingId': '123_abc', 'attendeeCount': 14},
      },
    ];
    return logs.map((json) => LogModel.fromJson(json)).toList();
  }

  @override
  Future<void> clearLogs() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<Map<String, dynamic>> fetchKvQuota() async {
    return {'day': DateTime.now().toIso8601String().substring(0, 10), 'writesTotal': 0, 'freeLimit': 1000, 'percentUsed': 0, 'remainingWrites': 1000};
  }
}
