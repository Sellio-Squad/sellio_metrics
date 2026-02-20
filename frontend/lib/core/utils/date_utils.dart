/// Sellio Metrics Dashboard — Date Utilities
///
/// Pure functions for date manipulation, week calculation, and formatting.
library;

import 'package:intl/intl.dart';

/// Returns the Monday (start) of the ISO week containing [date].
DateTime getWeekStartDate(DateTime date) {
  final weekday = date.weekday; // Monday = 1
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

/// Formats a week start date as "Mon DD – Mon DD" range.
String formatWeekHeader(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  final startFmt = DateFormat('MMM d').format(weekStart);
  final endFmt = DateFormat('MMM d').format(weekEnd);
  return '$startFmt – $endFmt';
}

/// Format a [DateTime] as ISO date string (YYYY-MM-DD).
String toIsoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Returns the ISO week key (e.g., "2026-W04") for a given date.
String getIsoWeekKey(DateTime date) {
  final start = getWeekStartDate(date);
  return start.toIso8601String();
}

/// Formats a [DateTime] as a short relative time (e.g., "2d ago", "3h ago").
String formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inDays > 30) {
    return '${(diff.inDays / 30).floor()}mo ago';
  } else if (diff.inDays > 0) {
    return '${diff.inDays}d ago';
  } else if (diff.inHours > 0) {
    return '${diff.inHours}h ago';
  } else if (diff.inMinutes > 0) {
    return '${diff.inMinutes}m ago';
  }
  return 'just now';
}

/// Formats [DateTime] as "MMM DD, YYYY" (e.g., "Jan 20, 2026").
String formatFullDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

/// Formats [DateTime] as "MMM DD" (e.g., "Jan 20").
String formatShortDate(DateTime date) => DateFormat('MMM d').format(date);
