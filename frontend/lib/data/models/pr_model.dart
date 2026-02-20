/// Sellio Metrics — PR Data Model
///
/// Strongly-typed model mapping the pr_metrics.json structure.
library;

/// A GitHub user reference.
class UserModel {
  final String login;
  final int id;
  final String url;
  final String avatarUrl;

  const UserModel({
    required this.login,
    required this.id,
    required this.url,
    this.avatarUrl = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        login: json['login'] as String? ?? '',
        id: json['id'] as int? ?? 0,
        url: json['url'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
      );
}

/// Aggregated comment data per author on a PR.
class CommentModel {
  final UserModel author;
  final DateTime? firstCommentAt;
  final DateTime? lastCommentAt;
  final int count;

  const CommentModel({
    required this.author,
    this.firstCommentAt,
    this.lastCommentAt,
    required this.count,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) => CommentModel(
        author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
        firstCommentAt: json['first_comment_at'] != null
            ? DateTime.parse(json['first_comment_at'] as String)
            : null,
        lastCommentAt: json['last_comment_at'] != null
            ? DateTime.parse(json['last_comment_at'] as String)
            : null,
        count: json['count'] as int? ?? 0,
      );
}

/// A review approval on a PR.
class ApprovalModel {
  final UserModel reviewer;
  final DateTime submittedAt;
  final String commitId;
  final String? note;

  const ApprovalModel({
    required this.reviewer,
    required this.submittedAt,
    required this.commitId,
    this.note,
  });

  factory ApprovalModel.fromJson(Map<String, dynamic> json) => ApprovalModel(
        reviewer:
            UserModel.fromJson(json['reviewer'] as Map<String, dynamic>),
        submittedAt: DateTime.parse(json['submitted_at'] as String),
        commitId: json['commit_id'] as String? ?? '',
        note: json['note'] as String?,
      );
}

/// Diff statistics for a PR.
class DiffStats {
  final int additions;
  final int deletions;
  final int changedFiles;

  const DiffStats({
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  int get totalChanges => additions + deletions;

  factory DiffStats.fromJson(Map<String, dynamic> json) => DiffStats(
        additions: json['additions'] as int? ?? 0,
        deletions: json['deletions'] as int? ?? 0,
        changedFiles: json['changed_files'] as int? ?? 0,
      );
}

/// Complete Pull Request model.
class PrModel {
  final int prNumber;
  final String url;
  final String title;
  final DateTime openedAt;
  final String headRef;
  final String baseRef;
  final UserModel creator;
  final List<UserModel> assignees;
  final List<CommentModel> comments;
  final List<ApprovalModel> approvals;
  final int requiredApprovals;
  final DateTime? firstApprovedAt;
  final double? timeToFirstApprovalMinutes;
  final DateTime? requiredApprovalsMetAt;
  final double? timeToRequiredApprovalsMinutes;
  final DateTime? closedAt;
  final DateTime? mergedAt;
  final UserModel? mergedBy;
  final String week;
  final String status;
  final DiffStats diffStats;
  final List<String> labels;
  final String? milestone;
  final bool draft;

  const PrModel({
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

  /// Total number of comments across all commenters.
  int get totalComments =>
      comments.fold(0, (sum, c) => sum + c.count);

  /// List of unique commenter logins.
  List<String> get commenterLogins =>
      comments.map((c) => c.author.login).toList();

  /// List of unique reviewer logins.
  List<String> get reviewerLogins =>
      approvals.map((a) => a.reviewer.login).toList();

  /// Whether this PR is currently open (not merged or closed).
  bool get isOpen => mergedAt == null && closedAt == null;

  /// Whether this PR has been merged.
  bool get isMerged => status == 'merged';

  /// Parse a single PR from JSON.
  factory PrModel.fromJson(Map<String, dynamic> json) => PrModel(
        prNumber: json['pr_number'] as int,
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        openedAt: DateTime.parse(json['opened_at'] as String),
        headRef: json['head_ref'] as String? ?? '',
        baseRef: json['base_ref'] as String? ?? '',
        creator:
            UserModel.fromJson(json['creator'] as Map<String, dynamic>),
        assignees: (json['assignees'] as List<dynamic>?)
                ?.map((e) => UserModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        comments: (json['comments'] as List<dynamic>?)
                ?.map(
                    (e) => CommentModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        approvals: (json['approvals'] as List<dynamic>?)
                ?.map(
                    (e) => ApprovalModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        requiredApprovals: json['required_approvals'] as int? ?? 2,
        firstApprovedAt: json['first_approved_at'] != null
            ? DateTime.parse(json['first_approved_at'] as String)
            : null,
        timeToFirstApprovalMinutes:
            (json['time_to_first_approval_minutes'] as num?)?.toDouble(),
        requiredApprovalsMetAt: json['required_approvals_met_at'] != null
            ? DateTime.parse(json['required_approvals_met_at'] as String)
            : null,
        timeToRequiredApprovalsMinutes:
            (json['time_to_required_approvals_minutes'] as num?)
                ?.toDouble(),
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
        mergedAt: json['merged_at'] != null
            ? DateTime.parse(json['merged_at'] as String)
            : null,
        mergedBy: json['merged_by'] != null
            ? UserModel.fromJson(json['merged_by'] as Map<String, dynamic>)
            : null,
        week: json['week'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        diffStats:
            DiffStats.fromJson(json['diff_stats'] as Map<String, dynamic>),
        labels: (json['labels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        milestone: json['milestone'] is Map
            ? (json['milestone'] as Map<String, dynamic>)['title'] as String?
            : json['milestone'] as String?,
        draft: json['draft'] as bool? ?? false,
      );
}
