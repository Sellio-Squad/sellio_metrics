/// PR Analysis Service
///
/// Pure analysis logic for PR insights, separated from entities.
/// All methods are static and side-effect-free for easy testing.
/// Designed for future AI provider swap — replace method bodies
/// without changing the interface.
library;

import '../entities/pr_code_insight.dart';
import '../entities/pr_entity.dart';
import '../enums/pr_size_category.dart';

class PrAnalysisService {
  const PrAnalysisService._();

  // ─── Size ──────────────────────────────────────────────────

  static PrSizeCategory categorizeSize(PrEntity pr) {
    return PrSizeCategory.fromTotalChanges(pr.diffStats.totalChanges);
  }

  static List<String> sizeHints(PrEntity pr) {
    final category = categorizeSize(pr);
    return switch (category) {
      PrSizeCategory.l => [
          'Large PR — consider splitting into smaller, focused PRs.',
          'Large PRs take 2–3× longer to review.',
        ],
      PrSizeCategory.xl => [
          'Extra-large PR — strongly consider splitting.',
          'PRs this size are statistically more likely to introduce bugs.',
          'Reviewers may skip details in very large diffs.',
        ],
      _ => [],
    };
  }

  // ─── Media Detection ───────────────────────────────────────

  static final _imagePattern = RegExp(
    r'\.(png|jpg|jpeg|gif|webp|svg)|!\[.*?\]\(.*?\)',
    caseSensitive: false,
  );

  static final _videoPattern = RegExp(
    r'\.(mp4|mov|webm|avi)|youtube\.com|youtu\.be|loom\.com|'
    r'https?://.*\.(mp4|mov|webm)',
    caseSensitive: false,
  );

  static bool hasImages(PrEntity pr) {
    return _imagePattern.hasMatch(pr.body);
  }

  static bool hasVideos(PrEntity pr) {
    return _videoPattern.hasMatch(pr.body);
  }

  /// +2 for images, +5 for videos.
  static int calculateBonusPoints(PrEntity pr) {
    int bonus = 0;
    if (hasImages(pr)) bonus += 2;
    if (hasVideos(pr)) bonus += 5;
    return bonus;
  }

  /// True if the PR should be "starred" (uploaded a video).
  static bool isStarred(PrEntity pr) => hasVideos(pr);

  // ─── Ticket Linking ────────────────────────────────────────

  static final _ticketPattern = RegExp(
    r'(?:^|\s|[(\[])([A-Z]{2,}-\d+)|#(\d+)',
    caseSensitive: false,
  );

  /// Extracts ticket ID from title, body, or labels.
  /// Returns `null` if no ticket is detected.
  static String? extractTicketId(PrEntity pr) {
    // Search in title first (most common placement)
    final sources = [pr.title, pr.body, ...pr.labels];
    for (final source in sources) {
      final match = _ticketPattern.firstMatch(source);
      if (match != null) {
        return match.group(1) ?? '#${match.group(2)}';
      }
    }
    return null;
  }

  /// True if no ticket is linked — signals a warning.
  static bool isMissingTicket(PrEntity pr) => extractTicketId(pr) == null;

  // ─── Code Insights ─────────────────────────────────────────

  /// Generates insights based on file extensions and PR metadata.
  /// This is the hook point for future AI-powered insights.
  static List<PrCodeInsight> generateInsights(PrEntity pr) {
    final insights = <PrCodeInsight>[];
    final files = pr.filesChanged;
    final category = categorizeSize(pr);

    // File-type analysis
    final dartFiles = files.where((f) => f.endsWith('.dart')).length;
    final testFiles =
        files.where((f) => f.contains('_test.dart') || f.contains('test/')).length;
    final configFiles = files
        .where((f) =>
            f.endsWith('.yaml') ||
            f.endsWith('.yml') ||
            f.endsWith('.json') ||
            f.endsWith('.toml'))
        .length;
    final ciFiles = files
        .where(
            (f) => f.contains('.github/') || f.contains('Dockerfile') || f.contains('Makefile'))
        .length;

    // Insights based on file analysis
    if (dartFiles > 0 && testFiles == 0 && category.isLarge) {
      insights.add(const PrCodeInsight(
        category: 'Testing',
        message: 'No test files detected in a large PR — consider adding tests.',
        severity: PrInsightSeverity.warning,
      ));
    }

    if (testFiles > 0) {
      insights.add(PrCodeInsight(
        category: 'Testing',
        message: '$testFiles test file(s) included — good coverage practice!',
        severity: PrInsightSeverity.tip,
      ));
    }

    if (configFiles > 0) {
      insights.add(PrCodeInsight(
        category: 'Configuration',
        message:
            '$configFiles config file(s) modified — verify CI and environment settings.',
        severity: PrInsightSeverity.warning,
      ));
    }

    if (ciFiles > 0) {
      insights.add(PrCodeInsight(
        category: 'CI/CD',
        message: 'CI/CD files modified — check pipeline status after merge.',
        severity: PrInsightSeverity.info,
      ));
    }

    // Dart-specific insights
    final pubspecChanged = files.any((f) => f.endsWith('pubspec.yaml'));
    if (pubspecChanged) {
      insights.add(const PrCodeInsight(
        category: 'Dependencies',
        message: 'pubspec.yaml changed — review dependency additions/updates.',
        severity: PrInsightSeverity.info,
      ));
    }

    final l10nFiles = files.where((f) => f.endsWith('.arb')).length;
    if (l10nFiles > 0) {
      insights.add(PrCodeInsight(
        category: 'Localization',
        message: '$l10nFiles localization file(s) modified — verify all languages updated.',
        severity: PrInsightSeverity.info,
      ));
    }

    // General insights
    if (pr.draft) {
      insights.add(const PrCodeInsight(
        category: 'Status',
        message: 'This is a draft PR — mark as ready when complete.',
        severity: PrInsightSeverity.info,
      ));
    }

    if (isMissingTicket(pr)) {
      insights.add(const PrCodeInsight(
        category: 'Tracking',
        message: 'No linked ticket detected — consider linking to a Jira/GitHub issue.',
        severity: PrInsightSeverity.warning,
      ));
    }

    // File-type breakdown as info
    if (files.isNotEmpty) {
      final extensions = <String, int>{};
      for (final file in files) {
        final dot = file.lastIndexOf('.');
        final ext = dot != -1 ? file.substring(dot) : '(no ext)';
        extensions[ext] = (extensions[ext] ?? 0) + 1;
      }
      final breakdown =
          extensions.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      insights.add(PrCodeInsight(
        category: 'Files',
        message: 'File types: $breakdown',
        severity: PrInsightSeverity.info,
      ));
    }

    return insights;
  }
}
