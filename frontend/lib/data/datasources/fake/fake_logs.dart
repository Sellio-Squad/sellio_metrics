
enum LogSeverity { info, warning, error, success }

enum LogCategory { github, googleMeet, system }

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

class FakeLogsDataSource {
  static List<LogEntry> generateLogs() {
    final now = DateTime.now();
    return [
      LogEntry(
        id: 'log_1',
        timestamp: now.subtract(const Duration(minutes: 2)),
        message: 'GitHub PR cache invalidated for sellio_mobile',
        severity: LogSeverity.info,
        category: LogCategory.github,
        metadata: {'repo': 'sellio_mobile', 'trigger': 'webhook:pull_request'},
      ),
      LogEntry(
        id: 'log_2',
        timestamp: now.subtract(const Duration(minutes: 5)),
        message: 'Google Meet attendees synchronisation completed',
        severity: LogSeverity.success,
        category: LogCategory.googleMeet,
        metadata: {'meetingId': '123_abc', 'attendeeCount': 14},
      ),
      LogEntry(
        id: 'log_3',
        timestamp: now.subtract(const Duration(minutes: 15)),
        message: 'GitHub API rate limit critical warning (15 remaining)',
        severity: LogSeverity.warning,
        category: LogCategory.github,
      ),
      LogEntry(
        id: 'log_4',
        timestamp: now.subtract(const Duration(minutes: 22)),
        message: 'API Route /api/metrics/leaderboard served from KV cache',
        severity: LogSeverity.info,
        category: LogCategory.system,
        metadata: {'latency_ms': 42},
      ),
      LogEntry(
        id: 'log_5',
        timestamp: now.subtract(const Duration(minutes: 45)),
        message: 'Failed to authenticate Google Workspace OAuth',
        severity: LogSeverity.error,
        category: LogCategory.googleMeet,
        metadata: {'error': 'invalid_grant', 'status_code': 401},
      ),
      LogEntry(
        id: 'log_6',
        timestamp: now.subtract(const Duration(hours: 1)),
        message: 'Cloudflare KV Cache quota reset completed',
        severity: LogSeverity.success,
        category: LogCategory.system,
      ),
      LogEntry(
        id: 'log_7',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
        message: 'Fetched 300 PRs from GitHub API for org: Sellio',
        severity: LogSeverity.info,
        category: LogCategory.github,
      ),
      LogEntry(
        id: 'log_8',
        timestamp: now.subtract(const Duration(hours: 2)),
        message: 'Meeting "Weekly Sync" auto-ended due to inactivity',
        severity: LogSeverity.info,
        category: LogCategory.googleMeet,
      ),
    ];
  }
}
