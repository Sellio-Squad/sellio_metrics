library;

class BottleneckConfig {
  const BottleneckConfig._();

  static const double defaultThresholdHours = 48;
  static const int maxDisplayCount = 10;
  static const double severityHighMultiplier = 3.0;
  static const double severityMediumMultiplier = 1.5;
}

class AnalyticsConfig {
  const AnalyticsConfig._();

  static const int requiredApprovals = 2;
  static const int topCollaboratorsCount = 5;
  static const int topDiscussedPrsCount = 5;
  static const double mergeTimeFastThreshold = 60; // minutes
  static const double mergeTimeSlowThreshold = 1440; // minutes (24h)
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

class AppTabs {
  const AppTabs._();

  static const String analytics = 'analytics';
  static const String openPrs = 'open_prs';
  static const String team = 'team';
  static const String settings = 'settings';

  static const List<String> all = [analytics, openPrs, team, settings];
}

class PrStatus {
  const PrStatus._();

  static const String merged = 'merged';
  static const String closed = 'closed';
  static const String pending = 'pending';
  static const String approved = 'approved';
}

/// Scoring weights for the leaderboard algorithm.
class LeaderboardWeights {
  const LeaderboardWeights._();

  static const int prsCreated = 3;
  static const int prsMerged = 2;
  static const int reviewsGiven = 2;
  static const int commentsGiven = 1;
}
