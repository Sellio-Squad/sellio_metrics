
/// Leaderboard entry for an individual team member.
class LeaderboardEntry {
  final String developer;
  final String? avatarUrl;
  final int prsCreated;
  final int prsMerged;
  final int reviewsGiven;
  final int commentsGiven;
  final int additions;
  final int deletions;
  final double totalScore;

  const LeaderboardEntry({
    required this.developer,
    this.avatarUrl,
    required this.prsCreated,
    required this.prsMerged,
    required this.reviewsGiven,
    required this.commentsGiven,
    required this.additions,
    required this.deletions,
    required this.totalScore,
  });
}
