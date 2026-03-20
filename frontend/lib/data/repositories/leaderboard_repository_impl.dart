/// Data — LeaderboardRepositoryImpl
///
/// Implements the domain LeaderboardRepository interface.
/// Depends on LeaderboardDataSource (interface, not concrete).
/// Maps raw JSON to domain LeaderboardEntry entities.
library;

import 'package:injectable/injectable.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_data_source.dart';

@LazySingleton(as: LeaderboardRepository)
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardDataSource _dataSource;

  LeaderboardRepositoryImpl(this._dataSource);

  @override
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final raw = await _dataSource.fetchLeaderboard();
    return raw.map(_toEntity).toList();
  }

  LeaderboardEntry _toEntity(dynamic json) {
    final m = json as Map<String, dynamic>;

    // Primary field names from the relational leaderboard API
    final login       = m['developer_login'] as String? ?? m['developer'] as String? ?? '';
    final displayName = m['displayName']     as String?;

    // Use displayName if available and different from login, otherwise fall back to login
    final name = (displayName != null && displayName.isNotEmpty && displayName != login)
        ? displayName
        : login;

    // Normalise avatar URL: convert github.com/user.png redirect → CDN URL
    final rawAvatar = m['avatarUrl'] as String? ?? m['avatar_url'] as String?;
    final avatarUrl = _normaliseAvatar(rawAvatar, login);

    // Current relational API fields
    final prCount      = m['pr_count']      as int? ?? 0;
    final commentCount = m['comment_count'] as int? ?? 0;

    // Fallback for older event_counts shape (if still in cache)
    final counts = m['event_counts'] as Map<String, dynamic>? ?? {};

    return LeaderboardEntry(
      developer:     name,
      avatarUrl:     avatarUrl,
      prsCreated:    prCount     != 0 ? prCount     : (counts['PR_MERGED']  as int? ?? 0),
      prsMerged:     prCount     != 0 ? prCount     : (counts['PR_MERGED']  as int? ?? 0),
      commentsGiven: commentCount != 0 ? commentCount : (counts['COMMENT'] as int? ?? 0),
      lineAdditions: m['line_additions'] as int? ?? counts['CODE_ADDITION'] as int? ?? 0,
      lineDeletions: m['line_deletions'] as int? ?? counts['CODE_DELETION'] as int? ?? 0,
      totalScore:    (m['total_points'] as num?)?.toDouble() ??
                     (m['totalScore']   as num?)?.toDouble() ??
                     0.0,
    );
  }

  /// Converts `https://github.com/username.png` redirect URLs to
  /// the final CDN URL format `https://avatars.githubusercontent.com/username`.
  /// If the URL is already CDN or null/empty, it's returned as-is.
  String? _normaliseAvatar(String? url, String login) {
    if (url == null || url.isEmpty) return null;
    // Already a CDN URL — no change needed
    if (url.startsWith('https://avatars.githubusercontent.com')) return url;
    // Convert https://github.com/username.png → CDN stable URL
    if (url.startsWith('https://github.com/') && url.endsWith('.png')) {
      return 'https://avatars.githubusercontent.com/$login';
    }
    return url;
  }
}
