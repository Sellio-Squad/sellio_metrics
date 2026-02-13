/// Sellio Metrics — KPI Service
///
/// Calculates KPI metrics and spotlight analytics from PR data.
library;

import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../entities/pr_entity.dart';
import '../entities/kpi_entity.dart';

class KpiService {
  const KpiService();

  /// Calculate KPI metrics from PR data.
  KpiEntity calculateKpis(
    List<PrEntity> prData, {
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

    return KpiEntity(
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
  SpotlightEntity calculateSpotlightMetrics(
    List<PrEntity> prData, {
    String developerFilter = 'all',
  }) {
    if (developerFilter != 'all') {
      final devPrs =
          prData.where((pr) => pr.creator.login == developerFilter).length;
      final commentedOn = prData
          .where((pr) => pr.commenterLogins.contains(developerFilter))
          .length;

      return SpotlightEntity(
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

    return SpotlightEntity(
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
}
