/// Sellio Metrics Dashboard — Formatters
///
/// Pure functions for formatting numbers, durations, and text.
library;

/// Formats a duration in minutes to a human-readable string.
///
/// Examples: "4m", "2h 15m", "3d 5h"
String formatDetailedDuration(double? minutes) {
  if (minutes == null || minutes < 0) return '—';

  if (minutes < 60) {
    return '${minutes.round()}m';
  } else if (minutes < 1440) {
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  } else {
    final days = (minutes / 1440).floor();
    final hours = ((minutes % 1440) / 60).round();
    return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  }
}

/// Formats a number with compact notation (e.g., 1.2K, 3.4M).
String formatCompactNumber(num value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

/// Formats additions/deletions as "+123 / -45".
String formatDiffStats(int additions, int deletions) {
  return '+$additions / -$deletions';
}

/// Formats a percentage (0-100) to "45.2%".
String formatPercentage(double value, {int decimals = 1}) {
  return '${value.toStringAsFixed(decimals)}%';
}

/// Truncate a string to [maxLength] with ellipsis.
String truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}
