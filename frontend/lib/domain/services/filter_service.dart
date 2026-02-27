/// Sellio Metrics — Filter Service
///
/// Handles PR filtering by week, search, status, and developer.
/// Also provides utility methods for available weeks/developers.
library;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../entities/pr_entity.dart';

class FilterService {
  const FilterService();

  /// Classify PR type from title.
  String classifyPrType(String title) {
    final lower = title.toLowerCase();
    for (final entry in PrTypePatterns.patterns.entries) {
      if (entry.value.hasMatch(lower)) return entry.key;
    }
    return 'other';
  }

  /// Analyze PR type distribution.
  Map<String, int> analyzePrTypes(List<PrEntity> prData) {
    final types = <String, int>{};
    for (final pr in prData) {
      final type = classifyPrType(pr.title);
      types[type] = (types[type] ?? 0) + 1;
    }
    return types;
  }

  /// Get unique week keys from PR data.
  List<String> getUniqueWeeks(List<PrEntity> prData) {
    final weekKeys = prData
        .map((pr) => getWeekStartDate(pr.openedAt).toIso8601String())
        .toSet()
        .toList();
    weekKeys.sort((a, b) => b.compareTo(a));
    return weekKeys;
  }

  /// Get unique developers from PR data.
  List<String> getUniqueDevelopers(List<PrEntity> prData) {
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
  List<PrEntity> filterByWeek(List<PrEntity> prData, String weekKey) {
    if (weekKey == FilterOptions.all) return prData;
    return prData.where((pr) {
      return getWeekStartDate(pr.openedAt).toIso8601String() == weekKey;
    }).toList();
  }

  /// Filter PRs by search term and status.
  List<PrEntity> filterPrs(
    List<PrEntity> prData, {
    String searchTerm = '',
    String statusFilter = FilterOptions.all,
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

    if (statusFilter != FilterOptions.all) {
      result = result.where((pr) => pr.status == statusFilter).toList();
    }

    return result;
  }

  /// Filter PRs by date range.
  List<PrEntity> filterByDateRange(
    List<PrEntity> prData,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) return prData;
    return prData.where((pr) {
      if (startDate != null && pr.openedAt.isBefore(startDate)) return false;
      if (endDate != null && pr.openedAt.isAfter(endDate)) return false;
      return true;
    }).toList();
  }
}
