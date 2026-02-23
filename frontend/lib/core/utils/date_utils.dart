library;

import '../constants/app_constants.dart';

/// Returns the Monday (start) of the ISO week containing [date].
DateTime getWeekStartDate(DateTime date) {
  final weekday = date.weekday; // Monday = 1
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

/// Formats a week start date as "Mon DD – Mon DD" range.
String formatWeekHeader(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  final startFmt = DateFormats.short.format(weekStart);
  final endFmt = DateFormats.short.format(weekEnd);
  return '$startFmt – $endFmt';
}

/// Format a [DateTime] as ISO date string (YYYY-MM-DD).
String toIsoDate(DateTime date) => DateFormats.iso.format(date);

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
String formatFullDate(DateTime date) => DateFormats.full.format(date);

/// Formats [DateTime] as "MMM DD" (e.g., "Jan 20").
String formatShortDate(DateTime date) => DateFormats.short.format(date);