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

    final login = m['developer_login'] as String? ?? m['developer'] as String? ?? '';
    final displayName = m['displayName']     as String?;

    final name = (displayName != null && displayName.isNotEmpty && displayName != login)
        ? displayName
        : login;

    final rawAvatar = m['avatarUrl'] as String? ?? m['avatar_url'] as String?;
    final avatarUrl = _normaliseAvatar(rawAvatar, login);
    final prCount = m['pr_count']      as int? ?? 0;
    final commentCount = m['comment_count'] as int? ?? 0;
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

  String? _normaliseAvatar(String? url, String login) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('https://avatars.githubusercontent.com')) return url;
    if (url.startsWith('https://github.com/') && url.endsWith('.png')) {
      return 'https://avatars.githubusercontent.com/$login';
    }
    return url;
  }
}
