/// Sellio Metrics — Analytics Service
///
/// Pure business logic for computing KPIs, bottnecks, spotlights, and more.
/// No Flutter/UI dependencies — fully testable.
library;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/pr_model.dart';
import '../../data/models/kpi_model.dart';
import '../../data/models/bottleneck_model.dart';
import '../../data/models/collaboration_model.dart';

class AnalyticsService {
  const AnalyticsService();

  /// Calculate KPI metrics from PR data.
  KpiModel calculateKpis(
    List<PrModel> prData, {
    String developerFilter = 'all',
  }) {
    var filtered = prData;

    if (developerFilter != 'all') {
      filtered = prData.where((pr) {
        return pr.creator.login == developerFilter ||
            pr.mergedBy?.login == developerFilter ||
            pr.reviewerLogins.contains(developerFilter);
      }).toList();
    }

    final totalPrs = filtered.length;
    final mergedPrs = filtered.where((pr) => pr.isMerged).length;
    final closedPrs =
        filtered.where((pr) => pr.status == PrStatus.closed).length;

    final totalAdd = filtered.fold(0, (s, pr) => s + pr.diffStats.additions);
    final totalDel = filtered.fold(0, (s, pr) => s + pr.diffStats.deletions);
    final avgAdd = totalPrs > 0 ? (totalAdd / totalPrs).round() : 0;
    final avgDel = totalPrs > 0 ? (totalDel / totalPrs).round() : 0;

    final totalComments = filtered.fold(0, (s, pr) => s + pr.totalComments);
    final avgComments = totalPrs > 0
        ? (totalComments / totalPrs).toStringAsFixed(1)
        : '0.0';

    final approvalTimes = filtered
        .map((pr) => pr.timeToFirstApprovalMinutes)
        .where((t) => t != null && t >= 0)
        .cast<double>()
        .toList();
    final avgApproval = approvalTimes.isNotEmpty
        ? approvalTimes.reduce((a, b) => a + b) / approvalTimes.length
        : null;

    final mergedData = filtered
        .where((pr) => pr.isMerged && pr.mergedAt != null)
        .toList();
    final lifespans = mergedData.map((pr) {
      return pr.mergedAt!.difference(pr.openedAt).inMinutes.toDouble();
    }).toList();
    final avgLifespan = lifespans.isNotEmpty
        ? lifespans.reduce((a, b) => a + b) / lifespans.length
        : null;

    return KpiModel(
      totalPrs: totalPrs,
      mergedPrs: mergedPrs,
      closedPrs: closedPrs,
      avgAdditions: avgAdd,
      avgDeletions: avgDel,
      totalComments: totalComments,
      avgComments: avgComments,
      avgApprovalTime: formatDetailedDuration(avgApproval),
      avgLifespan: formatDetailedDuration(avgLifespan),
    );
  }

  /// Calculate spotlight metrics.
  SpotlightModel calculateSpotlightMetrics(
    List<PrModel> prData, {
    String developerFilter = 'all',
  }) {
    if (developerFilter != 'all') {
      final devPrs =
          prData.where((pr) => pr.creator.login == developerFilter).length;
      final commentedOn = prData
          .where((pr) => pr.commenterLogins.contains(developerFilter))
          .length;

      return SpotlightModel(
        hotStreak: SpotlightMetric(
          user: developerFilter,
          label: 'Created $devPrs PRs',
          value: devPrs,
        ),
        topCommenter: SpotlightMetric(
          user: developerFilter,
          label: 'Commented on $commentedOn PRs',
          value: commentedOn,
        ),
      );
    }

    // Hot streak: most active
    final activity = <String, int>{};
    for (final pr in prData) {
      activity[pr.creator.login] = (activity[pr.creator.login] ?? 0) + 1;
      if (pr.mergedBy != null) {
        activity[pr.mergedBy!.login] =
            (activity[pr.mergedBy!.login] ?? 0) + 1;
      }
      for (final r in pr.reviewerLogins) {
        if (r != pr.creator.login) activity[r] = (activity[r] ?? 0) + 1;
      }
    }
    final hotStreakEntry = activity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Fastest reviewer
    final reviewTimes = <String, List<double>>{};
    for (final pr in prData) {
      if (pr.timeToFirstApprovalMinutes != null && pr.approvals.isNotEmpty) {
        final reviewer = pr.approvals.first.reviewer.login;
        reviewTimes.putIfAbsent(reviewer, () => []);
        reviewTimes[reviewer]!.add(pr.timeToFirstApprovalMinutes!);
      }
    }
    MapEntry<String, double>? fastestEntry;
    for (final entry in reviewTimes.entries) {
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      if (fastestEntry == null || avg < fastestEntry.value) {
        fastestEntry = MapEntry(entry.key, avg);
      }
    }

    // Top commenter
    final commenterCounts = <String, int>{};
    for (final pr in prData) {
      for (final c in pr.commenterLogins) {
        commenterCounts[c] = (commenterCounts[c] ?? 0) + 1;
      }
    }
    final topCommenterEntry = commenterCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SpotlightModel(
      hotStreak: hotStreakEntry.isNotEmpty
          ? SpotlightMetric(
              user: hotStreakEntry.first.key,
              label: '${hotStreakEntry.first.value} activities',
              value: hotStreakEntry.first.value,
            )
          : null,
      fastestReviewer: fastestEntry != null
          ? SpotlightMetric(
              user: fastestEntry.key,
              label:
                  'Avg. review: ${formatDetailedDuration(fastestEntry.value)}',
              value: fastestEntry.value,
            )
          : null,
      topCommenter: topCommenterEntry.isNotEmpty
          ? SpotlightMetric(
              user: topCommenterEntry.first.key,
              label: '${topCommenterEntry.first.value} PRs commented',
              value: topCommenterEntry.first.value,
            )
          : null,
    );
  }

  /// Identify bottleneck PRs (stuck in review too long).
  List<BottleneckModel> identifyBottlenecks(
    List<PrModel> prData, {
    double thresholdHours = BottleneckConfig.defaultThresholdHours,
  }) {
    final now = DateTime.now();

    final bottlenecks = prData
        .where((pr) => pr.isOpen)
        .map((pr) {
          final waitMs = now.difference(pr.openedAt).inMilliseconds;
          final waitHours = waitMs / (3600 * 1000);
          final waitDays = waitHours / 24;

          String severity = 'low';
          if (waitHours >= thresholdHours * BottleneckConfig.severityHighMultiplier) {
            severity = 'high';
          } else if (waitHours >= thresholdHours * BottleneckConfig.severityMediumMultiplier) {
            severity = 'medium';
          }

          return BottleneckModel(
            prNumber: pr.prNumber,
            title: pr.title,
            url: pr.url,
            author: pr.creator.login,
            waitTimeHours: waitHours,
            waitTimeDays: waitDays,
            severity: severity,
          );
        })
        .where((b) => b.waitTimeHours >= thresholdHours)
        .toList()
      ..sort((a, b) => b.waitTimeHours.compareTo(a.waitTimeHours));

    return bottlenecks.take(BottleneckConfig.maxDisplayCount).toList();
  }

  /// Calculate collaboration pairs.
  List<CollaborationPair> calculateCollaborationPairs(List<PrModel> prData) {
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
  List<LeaderboardEntry> calculateLeaderboard(List<PrModel> prData) {
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
      final total =
          a.prsCreated * 3 + a.prsMerged * 2 + a.reviewsGiven * 2 + a.commentsGiven;
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
  List<ReviewLoadEntry> calculateReviewLoad(List<PrModel> prData) {
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

  /// Classify PR type from title.
  String classifyPrType(String title) {
    final lower = title.toLowerCase();
    for (final entry in PrTypePatterns.patterns.entries) {
      if (entry.value.hasMatch(lower)) return entry.key;
    }
    return 'other';
  }

  /// Analyze PR type distribution.
  Map<String, int> analyzePrTypes(List<PrModel> prData) {
    final types = <String, int>{};
    for (final pr in prData) {
      final type = classifyPrType(pr.title);
      types[type] = (types[type] ?? 0) + 1;
    }
    return types;
  }

  /// Get unique week keys from PR data.
  List<String> getUniqueWeeks(List<PrModel> prData) {
    final weekKeys = prData
        .map((pr) => getWeekStartDate(pr.openedAt).toIso8601String())
        .toSet()
        .toList();
    weekKeys.sort((a, b) => b.compareTo(a));
    return weekKeys;
  }

  /// Get unique developers from PR data.
  List<String> getUniqueDevelopers(List<PrModel> prData) {
    final devs = <String>{};
    for (final pr in prData) {
      devs.add(pr.creator.login);
      if (pr.mergedBy != null) devs.add(pr.mergedBy!.login);
      devs.addAll(pr.reviewerLogins);
      devs.addAll(pr.commenterLogins);
    }
    final list = devs.toList()..sort();
    return list;
  }

  /// Filter PRs by week key.
  List<PrModel> filterByWeek(List<PrModel> prData, String weekKey) {
    if (weekKey == 'all') return prData;
    return prData.where((pr) {
      return getWeekStartDate(pr.openedAt).toIso8601String() == weekKey;
    }).toList();
  }

  /// Filter PRs by search term and status.
  List<PrModel> filterPrs(
    List<PrModel> prData, {
    String searchTerm = '',
    String statusFilter = 'all',
  }) {
    var result = prData;

    if (searchTerm.isNotEmpty) {
      final lower = searchTerm.toLowerCase();
      result = result.where((pr) {
        return pr.title.toLowerCase().contains(lower) ||
            pr.creator.login.toLowerCase().contains(lower) ||
            pr.prNumber.toString().contains(lower);
      }).toList();
    }

    if (statusFilter != 'all') {
      result = result.where((pr) => pr.status == statusFilter).toList();
    }

    return result;
  }
}

// Private accumulators — not part of public API.

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
