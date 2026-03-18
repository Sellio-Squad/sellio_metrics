class LeaderboardEntry {
  final String developer;
  final String? avatarUrl;
  final int prsCreated;
  final int prsMerged;
  final int commentsGiven;
  /// Actual number of lines added (sum across all repos).
  final int lineAdditions;
  /// Actual number of lines deleted (sum across all repos).
  final int lineDeletions;
  final double totalScore;

  const LeaderboardEntry({
    required this.developer,
    this.avatarUrl,
    required this.prsCreated,
    required this.prsMerged,
    required this.commentsGiven,
    required this.lineAdditions,
    required this.lineDeletions,
    required this.totalScore,
  });
}
