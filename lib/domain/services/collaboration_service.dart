/// Sellio Metrics — Collaboration Service
///
/// Computes collaboration pairs, leaderboard, and review load.
library;

import '../../core/constants/app_constants.dart';
import '../entities/pr_entity.dart';
import '../entities/collaboration_entity.dart';

class CollaborationService {
  const CollaborationService();

  /// Calculate collaboration pairs.
  List<CollaborationPair> calculateCollaborationPairs(List<PrEntity> prData) {
    final summary = <String, _CollabAccumulator>{};

    for (final pr in prData) {
      for (final reviewer in pr.reviewerLogins) {
        if (reviewer == pr.creator.login) continue;
        summary.putIfAbsent(reviewer, () => _CollabAccumulator());
        summary[reviewer]!.totalReviews++;
        summary[reviewer]!.collaborators.add(pr.creator.login);
      }
    }

    final pairs = summary.entries
        .map((e) => CollaborationPair(
              reviewer: e.key,
              totalReviews: e.value.totalReviews,
              collaborators: e.value.collaborators.toList(),
            ))
        .toList()
      ..sort((a, b) => b.totalReviews.compareTo(a.totalReviews));

    return pairs.take(AnalyticsConfig.topCollaboratorsCount).toList();
  }

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

  /// Calculate review load per developer.
  List<ReviewLoadEntry> calculateReviewLoad(List<PrEntity> prData) {
    final load = <String, _ReviewLoadAccumulator>{};

    for (final pr in prData) {
      final creator = pr.creator.login;
      load.putIfAbsent(creator, () => _ReviewLoadAccumulator());
      load[creator]!.prsCreated++;

      for (final reviewer in pr.reviewerLogins) {
        if (reviewer == creator) continue;
        load.putIfAbsent(reviewer, () => _ReviewLoadAccumulator());
        load[reviewer]!.reviewsGiven++;
      }
    }

    return load.entries.map((e) {
      final a = e.value;
      final ratio = a.prsCreated > 0
          ? a.reviewsGiven / a.prsCreated
          : a.reviewsGiven.toDouble();
      return ReviewLoadEntry(
        developer: e.key,
        reviewsGiven: a.reviewsGiven,
        prsCreated: a.prsCreated,
        reviewRatio: ratio,
      );
    }).toList()
      ..sort((a, b) => b.reviewsGiven.compareTo(a.reviewsGiven));
  }
}

// Private accumulators
class _CollabAccumulator {
  int totalReviews = 0;
  final Set<String> collaborators = {};
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
