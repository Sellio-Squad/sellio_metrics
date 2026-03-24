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
  static String meetingDetail(String id)       => '/api/meetings/$id';
  static String meetingEnd(String id)          => '/api/meetings/$id/end';
  static String meetingParticipants(String id) => '/api/meetings/$id/participants';

  // ─── Meetings — WebSocket (real-time) ───
  /// Returns a ws:// or wss:// URL for the meeting's Durable Object.
  static String meetingWs(String id) {
    // Replace http(s) scheme with ws(s) from the base URL
    const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'wss://sellio-metrics.abdoessam743.workers.dev');
    return '$base/api/meetings/$id/ws';
  }

  // ─── Meet Auth (Google OAuth) ───
  static const meetAuthStatus = '/api/meetings/auth-status';
  static const meetAuthUrl    = '/api/meetings/auth-url';
  static const meetAuthLogout = '/api/meetings/auth-logout';

  // ─── Sync ───
  static const syncGithub = '/api/sync/github';
  static const syncGithubReset = '/api/sync/github/reset';
}
