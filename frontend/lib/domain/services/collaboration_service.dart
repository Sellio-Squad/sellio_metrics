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
      scores[creator]!.avatarUrl ??= pr.creator.avatarUrl;
      if (pr.isMerged) scores[creator]!.prsMerged++;

      for (final approval in pr.approvals) {
        final reviewer = approval.reviewer.login;
        if (reviewer == creator) continue;
        scores.putIfAbsent(reviewer, () => _LeaderboardAccumulator());
        scores[reviewer]!.reviewsGiven++;
        scores[reviewer]!.avatarUrl ??= approval.reviewer.avatarUrl;
      }

      for (final comment in pr.comments) {
        final commenter = comment.author.login;
        scores.putIfAbsent(commenter, () => _LeaderboardAccumulator());
        scores[commenter]!.commentsGiven++;
        scores[commenter]!.avatarUrl ??= comment.author.avatarUrl;
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
        avatarUrl: a.avatarUrl,
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
  String? avatarUrl;
  int prsCreated = 0;
  int prsMerged = 0;
  int reviewsGiven = 0;
  int commentsGiven = 0;
}