library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ApiConfig {
  const ApiConfig._();

  /// Base URL for the TypeScript backend.
  /// Uses localhost in debug mode, configure for production deployment.
  static String get baseUrl {
    if (kDebugMode) {
      return 'http://localhost:3001';
    }
    // TODO: Replace with your production backend URL
    return 'http://localhost:3001';
  }

  static const String defaultOrg = 'Sellio-Squad';
  static const String defaultRepo = 'sellio_mobile';
}

class BottleneckConfig {
  const BottleneckConfig._();

  static const double defaultThresholdHours = 48;
  static const int maxDisplayCount = 10;
  static const double severityHighMultiplier = 3.0;
  static const double severityMediumMultiplier = 1.5;
}

class PrTypePatterns {
  const PrTypePatterns._();

  static final Map<String, RegExp> patterns = {
    'feature': RegExp(r'feat(ure)?[:\/(]', caseSensitive: false),
    'fix': RegExp(r'fix[:\/(]|bug', caseSensitive: false),
    'refactor': RegExp(r'refactor[:\/(]', caseSensitive: false),
    'chore': RegExp(r'chore[:\/(]', caseSensitive: false),
    'docs': RegExp(r'docs?[:\/(]', caseSensitive: false),
    'ci': RegExp(r'ci[:\/(]', caseSensitive: false),
    'test': RegExp(r'test[:\/(]', caseSensitive: false),
    'style': RegExp(r'style[:\/(]', caseSensitive: false),
  };
}

class StorageKeys {
  const StorageKeys._();

  static const String theme = 'sellio_theme';
  static const String settings = 'sellio_settings';
  static const String filters = 'sellio_filters';
}

class PrStatus {
  const PrStatus._();

  static const String merged = 'merged';
  static const String closed = 'closed';
  static const String pending = 'pending';
  static const String approved = 'approved';
}

class FilterOptions {
  const FilterOptions._();

  static const String all = 'all';
}

/// Scoring weights for the leaderboard algorithm.
class LeaderboardWeights {
  const LeaderboardWeights._();

  static const int prsCreated = 3;
  static const int prsMerged = 2;
  static const int reviewsGiven = 0;
  static const int commentsGiven = 1;
}

class DateFormats {
  const DateFormats._();

  static final full = DateFormat('MMM d, yyyy');
  static final short = DateFormat('MMM d');
  static final iso = DateFormat('yyyy-MM-dd');
}
