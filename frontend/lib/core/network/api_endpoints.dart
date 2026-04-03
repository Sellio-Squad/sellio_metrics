// core/network/api_endpoints.dart

/// Single source of truth for all backend routes.
/// 
/// Grouped by feature. Update here when backend API changes.
class ApiEndpoints {
  ApiEndpoints._();

  // ─── Members ───
  static const members = '/api/members';

  // ─── Leaderboard ───
  static const leaderboard = '/api/scores/leaderboard';

  // ─── PRs ───
  static const prs = '/api/prs';

  // ─── Repos ───
  static const repos = '/api/repos';
  static const reposSynced = '/api/repos/synced';

  // ─── Logs ───
  static const logs      = '/api/logs';
  static const logsQuota = '/api/logs/quota';

  // ─── Health ───
  static const health = '/api/health';
  static const cacheQuota = '/api/debug/cache-quota';

  // ─── Meetings ───
  static const meetings = '/api/meetings';
  static String meetingDetail(String id)       => '/api/meetings/$id';
  static String meetingEnd(String id)          => '/api/meetings/$id/end';
  static String meetingParticipants(String id) => '/api/meetings/$id/participants';

  // ─── Meetings — WebSocket (real-time) ───
  /// Returns a ws:// or wss:// URL for the meeting's Durable Object.
  static String meetingWs(String id) {
    var base = const String.fromEnvironment('API_BASE_URL', defaultValue: 'wss://sellio-metrics.abdoessam743.workers.dev');
    if (base.startsWith('https://')) {
      base = base.replaceFirst('https://', 'wss://');
    } else if (base.startsWith('http://')) {
      base = base.replaceFirst('http://', 'ws://');
    }
    return '$base/api/meetings/$id/ws';
  }

  // ─── Meet Auth (Google OAuth) ───
  static const meetAuthStatus = '/api/meetings/auth-status';
  static const meetAuthUrl    = '/api/meetings/auth-url';
  static const meetAuthLogout = '/api/meetings/auth-logout';

  // ─── Regular Meeting Schedules ───
  static const meetingSchedules           = '/api/meetings/schedules';
  static String meetingScheduleById(String id) => '/api/meetings/schedules/$id';

  // ─── Sync ───
  static const syncGithub = '/api/sync/github';
  static const syncGithubReset = '/api/sync/github/reset';
  static const syncGithubCache = '/api/sync/github/cache';
  static String syncJobStatus(String jobId) => '/api/sync/status/$jobId';

  // ─── Review ───
  static const reviewPr    = '/api/review/pr';
  static const reviewUsage = '/api/review/usage';
  static const reviewMeta  = '/api/review/meta';
}
