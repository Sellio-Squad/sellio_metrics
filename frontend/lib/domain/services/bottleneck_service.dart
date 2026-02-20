/// Sellio Metrics — Bottleneck Service
///
/// Identifies PRs stuck in review too long.
library;

import '../../core/constants/app_constants.dart';
import '../entities/pr_entity.dart';
import '../entities/bottleneck_entity.dart';
import '../enums/severity.dart';

class BottleneckService {
  const BottleneckService();

  /// Identify bottleneck PRs (stuck in review too long).
  List<BottleneckEntity> identifyBottlenecks(
    List<PrEntity> prData, {
    double thresholdHours = BottleneckConfig.defaultThresholdHours,
  }) {
    final now = DateTime.now();

    final bottlenecks = prData
        .where((pr) => pr.isOpen)
        .map((pr) {
          final waitMs = now.difference(pr.openedAt).inMilliseconds;
          final waitHours = waitMs / (3600 * 1000);
          final waitDays = waitHours / 24;

          final severity = _classifySeverity(waitHours, thresholdHours);

          return BottleneckEntity(
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

  Severity _classifySeverity(double waitHours, double thresholdHours) {
    if (waitHours >= thresholdHours * BottleneckConfig.severityHighMultiplier) {
      return Severity.high;
    } else if (waitHours >=
        thresholdHours * BottleneckConfig.severityMediumMultiplier) {
      return Severity.medium;
    }
    return Severity.low;
  }
}
