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

  // ─── Logs ───
  static const logs = '/api/logs';

  // ─── Health ───
  static const health = '/api/health';
  static const cacheQuota = '/api/debug/cache-quota';

  // ─── Meetings ───
  static const meetings = '/api/meetings';
  static String meetingDetail(String id) => '/api/meetings/$id';
  static String meetingEnd(String id) => '/api/meetings/$id/end';
  static String meetingAttendance(String id) => '/api/meetings/$id/attendance';
  static const meetingAnalytics = '/api/meetings/analytics';
  static const meetingRateLimit = '/api/meetings/rate-limit';

  // ─── Meet Auth (Google OAuth) ───
  static const meetAuthStatus = '/api/meetings/auth/status';
  static const meetAuthUrl = '/api/meetings/auth/url';
  static const meetAuthLogout = '/api/auth/logout';

  // ─── Meet Events (SSE) ───
  static const meetEventsSubscribe = '/api/meet-events/subscribe';
  static const meetEventsStream = '/api/meet-events/stream';
  static const meetEventsList = '/api/meet-events/events';
  static const meetEventsSubscriptions = '/api/meet-events/subscriptions';

  // ─── Sync ───
  static const syncGithub = '/api/sync/github';
  static const syncGithubReset = '/api/sync/github/reset';
}
