/// Sellio Metrics — Collaboration Service
///
/// Computes collaboration pairs, leaderboard, and review load.
library;

import '../../core/constants/app_constants.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/pr_entity.dart';

class CollaborationService {
  const CollaborationService();

  /// Calculate leaderboard entries.
  List<LeaderboardEntry> calculateLeaderboard(List<PrEntity> prData) {
    final scores = <String, _LeaderboardAccumulator>{};

    for (final pr in prData) {
      final creator = pr.creator.login;
      scores.putIfAbsent(creator, () => _LeaderboardAccumulator());
      scores[creator]!.prsCreated++;
      if (pr.isMerged) scores[creator]!.prsMerged++;

      for (final reviewer in pr.reviewerLogins) {
        if (reviewer == creator) continue;
        scores.putIfAbsent(reviewer, () => _LeaderboardAccumulator());
        scores[reviewer]!.reviewsGiven++;
      }

      for (final commenter in pr.commenterLogins) {
        scores.putIfAbsent(commenter, () => _LeaderboardAccumulator());
        scores[commenter]!.commentsGiven++;
      }
    }

    return scores.entries.map((e) {
      final a = e.value;
      final total = a.prsCreated * LeaderboardWeights.prsCreated +
          a.prsMerged * LeaderboardWeights.prsMerged +
          a.reviewsGiven * LeaderboardWeights.reviewsGiven +
          a.commentsGiven * LeaderboardWeights.commentsGiven;
      return LeaderboardEntry(
        developer: e.key,
        prsCreated: a.prsCreated,
        prsMerged: a.prsMerged,
        reviewsGiven: a.reviewsGiven,
        commentsGiven: a.commentsGiven,
        totalScore: total,
      );
    }).toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
  }
}


class _LeaderboardAccumulator {
  int prsCreated = 0;
  int prsMerged = 0;
  int reviewsGiven = 0;
  int commentsGiven = 0;
}

class _ReviewLoadAccumulator {
  int reviewsGiven = 0;
  int prsCreated = 0;
}
