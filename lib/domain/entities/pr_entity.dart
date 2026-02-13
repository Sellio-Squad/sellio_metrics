/// Sellio Metrics — Domain Entities
///
/// Core business types owned by the domain layer.
/// Data models map to/from these; presentation consumes these.
/// No JSON parsing here — that's a data-layer concern.
library;

/// A GitHub user reference.
class UserEntity {
  final String login;
  final int id;
  final String url;
  final String avatarUrl;

  const UserEntity({
    required this.login,
    required this.id,
    this.url = '',
    this.avatarUrl = '',
  });
}

/// Aggregated comment data per author on a PR.
class CommentEntity {
  final UserEntity author;
  final DateTime? firstCommentAt;
  final DateTime? lastCommentAt;
  final int count;

  const CommentEntity({
    required this.author,
    this.firstCommentAt,
    this.lastCommentAt,
    required this.count,
  });
}

/// A review approval on a PR.
class ApprovalEntity {
  final UserEntity reviewer;
  final DateTime submittedAt;
  final String commitId;
  final String? note;

  const ApprovalEntity({
    required this.reviewer,
    required this.submittedAt,
    required this.commitId,
    this.note,
  });
}

/// Diff statistics for a PR.
class DiffStatsEntity {
  final int additions;
  final int deletions;
  final int changedFiles;

  const DiffStatsEntity({
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  int get totalChanges => additions + deletions;
}

/// Complete Pull Request entity.
class PrEntity {
  final int prNumber;
  final String url;
  final String title;
  final DateTime openedAt;
  final String headRef;
  final String baseRef;
  final UserEntity creator;
  final List<UserEntity> assignees;
  final List<CommentEntity> comments;
  final List<ApprovalEntity> approvals;
  final int requiredApprovals;
  final DateTime? firstApprovedAt;
  final double? timeToFirstApprovalMinutes;
  final DateTime? requiredApprovalsMetAt;
  final double? timeToRequiredApprovalsMinutes;
  final DateTime? closedAt;
  final DateTime? mergedAt;
  final UserEntity? mergedBy;
  final String week;
  final String status;
  final DiffStatsEntity diffStats;
  final List<String> labels;
  final String? milestone;
  final bool draft;

  const PrEntity({
    required this.prNumber,
    required this.url,
    required this.title,
    required this.openedAt,
    required this.headRef,
    required this.baseRef,
    required this.creator,
    required this.assignees,
    required this.comments,
    required this.approvals,
    required this.requiredApprovals,
    this.firstApprovedAt,
    this.timeToFirstApprovalMinutes,
    this.requiredApprovalsMetAt,
    this.timeToRequiredApprovalsMinutes,
    this.closedAt,
    this.mergedAt,
    this.mergedBy,
    required this.week,
    required this.status,
    required this.diffStats,
    this.labels = const [],
    this.milestone,
    this.draft = false,
  });

  int get totalComments => comments.fold(0, (sum, c) => sum + c.count);

  List<String> get commenterLogins =>
      comments.map((c) => c.author.login).toList();

  List<String> get reviewerLogins =>
      approvals.map((a) => a.reviewer.login).toList();

  bool get isOpen => mergedAt == null && closedAt == null;

  bool get isMerged => status == 'merged';
}
