// ─── Domain Entity: Review ──────────────────────────────────────────────────

enum ReviewSeverity { critical, warning, info }

extension ReviewSeverityX on ReviewSeverity {
  static ReviewSeverity fromString(String value) {
    switch (value) {
      case 'critical':
        return ReviewSeverity.critical;
      case 'warning':
        return ReviewSeverity.warning;
      default:
        return ReviewSeverity.info;
    }
  }

  String get label {
    switch (this) {
      case ReviewSeverity.critical:
        return 'Critical';
      case ReviewSeverity.warning:
        return 'Warning';
      case ReviewSeverity.info:
        return 'Info';
    }
  }
}

class ReviewFindingEntity {
  final String file;
  final int? line;
  final ReviewSeverity severity;
  final String title;
  final String description;
  final String? suggestion;

  const ReviewFindingEntity({
    required this.file,
    this.line,
    required this.severity,
    required this.title,
    required this.description,
    this.suggestion,
  });
}

class ReviewPrInfoEntity {
  final int number;
  final String title;
  final String author;
  final String url;
  final String state;
  final int additions;
  final int deletions;
  final int changedFiles;
  final DateTime createdAt;
  final String? body;

  const ReviewPrInfoEntity({
    required this.number,
    required this.title,
    required this.author,
    required this.url,
    required this.state,
    required this.additions,
    required this.deletions,
    required this.changedFiles,
    required this.createdAt,
    this.body,
  });
}

class ReviewEntity {
  final ReviewPrInfoEntity pr;
  final String prSummary;
  final List<ReviewFindingEntity> bugs;
  final List<ReviewFindingEntity> bestPractices;
  final List<ReviewFindingEntity> security;
  final List<ReviewFindingEntity> performance;
  final bool hasIssues;
  final DateTime reviewedAt;

  const ReviewEntity({
    required this.pr,
    required this.prSummary,
    required this.bugs,
    required this.bestPractices,
    required this.security,
    required this.performance,
    required this.hasIssues,
    required this.reviewedAt,
  });

  int get totalIssues =>
      bugs.length + bestPractices.length + security.length + performance.length;

  int get criticalCount => [
        ...bugs,
        ...bestPractices,
        ...security,
        ...performance,
      ].where((f) => f.severity == ReviewSeverity.critical).length;
}
