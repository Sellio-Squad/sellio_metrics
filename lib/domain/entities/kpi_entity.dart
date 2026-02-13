/// Sellio Metrics — KPI Domain Entities
library;

/// Computed KPI metrics.
class KpiEntity {
  final int totalPrs;
  final int mergedPrs;
  final int closedPrs;
  final int avgAdditions;
  final int avgDeletions;
  final int totalComments;
  final String avgComments;
  final String avgApprovalTime;
  final String avgLifespan;

  const KpiEntity({
    required this.totalPrs,
    required this.mergedPrs,
    required this.closedPrs,
    required this.avgAdditions,
    required this.avgDeletions,
    required this.totalComments,
    required this.avgComments,
    required this.avgApprovalTime,
    required this.avgLifespan,
  });

  String get avgPrSize => '+$avgAdditions / -$avgDeletions';

  double get mergeRate => totalPrs > 0 ? (mergedPrs / totalPrs) * 100 : 0;
}

/// Spotlight metric (hot streak, fastest reviewer, etc.)
class SpotlightMetric {
  final String user;
  final String label;
  final num value;

  const SpotlightMetric({
    required this.user,
    required this.label,
    required this.value,
  });
}

/// Spotlight metrics collection.
class SpotlightEntity {
  final SpotlightMetric? hotStreak;
  final SpotlightMetric? fastestReviewer;
  final SpotlightMetric? topCommenter;

  const SpotlightEntity({
    this.hotStreak,
    this.fastestReviewer,
    this.topCommenter,
  });
}
