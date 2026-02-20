/// Sellio Metrics Dashboard — UI Strings
///
/// Centralized string resources for localization readiness.
library;

class AppStrings {
  const AppStrings._();

  // App
  static const String appTitle = 'Sellio Squad Dashboard';
  static const String appSubtitle = 'Team Metrics & Analytics';

  // Navigation
  static const String navAnalytics = 'Analytics';
  static const String navOpenPrs = 'Open PRs';
  static const String navTeam = 'Team';
  static const String navSettings = 'Settings';

  // KPI Labels
  static const String kpiTotalPrs = 'Total PRs';
  static const String kpiMergedPrs = 'Merged PRs';
  static const String kpiClosedPrs = 'Closed PRs';
  static const String kpiAvgPrSize = 'Avg. PR Size';
  static const String kpiTotalComments = 'Total Comments';
  static const String kpiAvgComments = 'Avg. Comments / PR';
  static const String kpiAvgApproval = 'Avg. Time to Approval';
  static const String kpiAvgLifespan = 'Avg. PR Lifespan';

  // Filters
  static const String filterAllTime = 'All Time';
  static const String filterCurrentWeek = 'Current Week';
  static const String filterAllTeam = 'All Team';
  static const String filterByWeek = 'Filter by Week';
  static const String filterViewAs = 'View as';

  // Sections
  static const String sectionBottlenecks = 'Bottleneck Analysis';
  static const String sectionOpenPrs = 'Open Pull Requests';
  static const String sectionLeaderboard = 'Leaderboard';
  static const String sectionReviewLoad = 'Review Load';
  static const String sectionCollaboration = 'Top Collaboration Pairs';
  static const String sectionSpotlight = 'Spotlight';

  // Spotlight
  static const String spotlightHotStreak = '🔥 Hot Streak';
  static const String spotlightFastestReviewer = '⚡ Fastest Reviewer';
  static const String spotlightTopCommenter = '💬 Top Commenter';

  // Bottleneck
  static const String bottleneckSeverityHigh = 'High';
  static const String bottleneckSeverityMedium = 'Medium';
  static const String bottleneckSeverityLow = 'Low';
  static const String bottleneckWaiting = 'waiting';

  // Settings
  static const String settingsThreshold = 'Bottleneck Threshold (hours)';
  static const String settingsNotifications = 'Enable Notifications';
  static const String settingsTheme = 'Dark Mode';
  static const String settingsRequiredApprovals = 'Required Approvals';

  // Search
  static const String searchPlaceholder = 'Search PRs by title, author…';
  static const String searchNoResults = 'No pull requests match your filters.';

  // Status
  static const String statusMerged = 'Merged';
  static const String statusPending = 'Pending';
  static const String statusClosed = 'Closed';
  static const String statusApproved = 'Approved';

  // Export
  static const String exportCsv = 'Export CSV';
  static const String exportTitle = 'Export Data';

  // Empty states
  static const String emptyData = 'No data available';
  static const String loadingData = 'Loading dashboard data…';

  // Merge health
  static const String mergeHealthExcellent =
      'Excellent! PRs are merged quickly after approval.';
  static const String mergeHealthGood =
      'Good pace. Most PRs merge within a day of approval.';
  static const String mergeHealthNeedsImprovement =
      'PRs are taking too long after approval. Consider faster merges.';
  static const String mergeHealthNoData =
      'Not enough merged PRs to calculate health.';
}
