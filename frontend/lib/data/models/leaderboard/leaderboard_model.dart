class LeaderboardModel {
  final String developer;
  final String? avatarUrl;
  final int prsCreated;
  final int prsMerged;
  final int commentsGiven;
  final int commitCount;
  final int lineAdditions;
  final int lineDeletions;
  final double totalScore;

  const LeaderboardModel({
    required this.developer,
    this.avatarUrl,
    required this.prsCreated,
    required this.prsMerged,
    required this.commentsGiven,
    required this.commitCount,
    required this.lineAdditions,
    required this.lineDeletions,
    required this.totalScore,
  });

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    final m = json;
    final login = m['developer_login'] as String? ?? m['developer'] as String? ?? '';
    final displayName = m['displayName'] as String?;
    final name = (displayName != null && displayName.isNotEmpty && displayName != login)
        ? displayName
        : login;

    final prCount = m['pr_count'] as int? ?? 0;
    final commentCount = m['comment_count'] as int? ?? 0;
    final commitCnt = m['commit_count'] as int? ?? 0;
    final counts = m['event_counts'] as Map<String, dynamic>? ?? {};

    return LeaderboardModel(
      developer: name,
      avatarUrl: m['avatarUrl'] as String? ?? m['avatar_url'] as String?,
      prsCreated: prCount != 0 ? prCount : (counts['PR_MERGED'] as int? ?? 0),
      prsMerged: prCount != 0 ? prCount : (counts['PR_MERGED'] as int? ?? 0),
      commentsGiven: commentCount != 0 ? commentCount : (counts['COMMENT'] as int? ?? 0),
      commitCount: commitCnt != 0 ? commitCnt : (counts['COMMIT'] as int? ?? 0),
      lineAdditions: m['line_additions'] as int? ?? counts['CODE_ADDITION'] as int? ?? 0,
      lineDeletions: m['line_deletions'] as int? ?? counts['CODE_DELETION'] as int? ?? 0,
      totalScore: (m['total_points'] as num?)?.toDouble() ??
          (m['totalScore'] as num?)?.toDouble() ??
          (m['total_score'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'developer': developer,
      'avatarUrl': avatarUrl,
      'prs_created': prsCreated,
      'prs_merged': prsMerged,
      'comments_given': commentsGiven,
      'commit_count': commitCount,
      'line_additions': lineAdditions,
      'line_deletions': lineDeletions,
      'total_score': totalScore,
    };
  }
}
