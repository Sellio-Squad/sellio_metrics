/// Sellio Metrics — Collaboration Domain Entities
library;

/// A paired collaboration between a reviewer and their collaborators.
class CollaborationPair {
  final String reviewer;
  final int totalReviews;
  final List<String> collaborators;

  const CollaborationPair({
    required this.reviewer,
    required this.totalReviews,
    required this.collaborators,
  });
}

/// Review load entry for an individual developer.
class ReviewLoadEntry {
  final String developer;
  final int reviewsGiven;
  final int prsCreated;
  final double reviewRatio;

  const ReviewLoadEntry({
    required this.developer,
    required this.reviewsGiven,
    required this.prsCreated,
    required this.reviewRatio,
  });
}

/// Leaderboard entry for an individual developer.
class LeaderboardEntry {
  final String developer;
  final int prsCreated;
  final int prsMerged;
  final int reviewsGiven;
  final int commentsGiven;
  final int totalScore;

  const LeaderboardEntry({
    required this.developer,
    required this.prsCreated,
    required this.prsMerged,
    required this.reviewsGiven,
    required this.commentsGiven,
    required this.totalScore,
  });
}
