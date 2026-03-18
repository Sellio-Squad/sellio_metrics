library;

import 'pr_timeline_event.dart';
import 'approval_entity.dart';
import 'comment_entity.dart';
import 'diff_stats_entity.dart';
import 'user_entity.dart';

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
  final String body;
  final List<String> reviewRequests;
  final List<String> filesChanged;

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
    this.body = '',
    this.reviewRequests = const [],
    this.filesChanged = const [],
  });

  factory PrEntity.fromJson(Map<String, dynamic> json) {
    // Parse approvals
    final rawApprovals = json['approvals'] as List<dynamic>? ?? [];
    final approvals = rawApprovals.map((a) {
      final reviewer = a['reviewer'] as Map<String, dynamic>? ?? {};
      return ApprovalEntity(
        reviewer: UserEntity(
          id: reviewer['id'] as int? ?? 0,
          login: reviewer['login'] as String? ?? 'unknown',
          avatarUrl: reviewer['avatar_url'] as String? ?? '',
        ),
        submittedAt: DateTime.tryParse(a['submitted_at']?.toString() ?? '') ?? DateTime.now(),
        commitId: a['commit_id'] as String? ?? '',
        note: a['note'] as String?,
      );
    }).toList();

    // Parse comments (grouped by author from backend)
    final rawComments = json['comments'] as List<dynamic>? ?? [];
    final comments = rawComments.map((c) {
      final author = c['author'] as Map<String, dynamic>? ?? {};
      return CommentEntity(
        author: UserEntity(
          id: author['id'] as int? ?? 0,
          login: author['login'] as String? ?? 'unknown',
          avatarUrl: author['avatar_url'] as String? ?? '',
        ),
        firstCommentAt: c['first_comment_at'] != null
            ? DateTime.tryParse(c['first_comment_at'].toString())
            : null,
        lastCommentAt: c['last_comment_at'] != null
            ? DateTime.tryParse(c['last_comment_at'].toString())
            : null,
        count: c['count'] as int? ?? 1,
      );
    }).toList();

    // Parse mergedBy
    final mergedByRaw = json['merged_by'] as Map<String, dynamic>?;
    final mergedBy = mergedByRaw != null
        ? UserEntity(
            id: mergedByRaw['id'] as int? ?? 0,
            login: mergedByRaw['login'] as String? ?? 'unknown',
            avatarUrl: mergedByRaw['avatar_url'] as String? ?? '',
          )
        : null;

    return PrEntity(
      prNumber: json['pr_number'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled PR',
      openedAt: DateTime.tryParse(json['opened_at']?.toString() ?? '') ?? DateTime.now(),
      headRef: json['head_ref'] as String? ?? '',
      baseRef: json['base_ref'] as String? ?? '',
      creator: UserEntity(
        id: json['creator']?['id'] as int? ?? 0,
        login: json['creator']?['login'] as String? ?? 'unknown',
        avatarUrl: json['creator']?['avatar_url'] as String? ?? '',
      ),
      assignees: (json['assignees'] as List<dynamic>?)?.map((e) => UserEntity(
        id: e['id'] as int? ?? 0,
        login: e['login'] as String? ?? 'unknown',
        avatarUrl: e['avatar_url'] as String? ?? '',
      )).toList() ?? [],
      comments: comments,
      approvals: approvals,
      requiredApprovals: json['required_approvals'] as int? ?? 0,
      firstApprovedAt: json['first_approved_at'] != null
          ? DateTime.tryParse(json['first_approved_at'].toString())
          : null,
      timeToFirstApprovalMinutes:
          (json['time_to_first_approval_minutes'] as num?)?.toDouble(),
      requiredApprovalsMetAt: json['required_approvals_met_at'] != null
          ? DateTime.tryParse(json['required_approvals_met_at'].toString())
          : null,
      timeToRequiredApprovalsMinutes:
          (json['time_to_required_approvals_minutes'] as num?)?.toDouble(),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      mergedAt: json['merged_at'] != null
          ? DateTime.tryParse(json['merged_at'].toString())
          : null,
      mergedBy: mergedBy,
      week: json['week'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      diffStats: DiffStatsEntity(
        additions: json['diff_stats']?['additions'] as int? ?? 0,
        deletions: json['diff_stats']?['deletions'] as int? ?? 0,
        changedFiles: json['diff_stats']?['changed_files'] as int? ?? 0,
      ),
      labels: (json['labels'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      milestone: (json['milestone'] as Map<String, dynamic>?)?['title'] as String?,
      draft: json['draft'] as bool? ?? false,
      body: json['body'] as String? ?? '',
      reviewRequests: (json['review_requests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      filesChanged: (json['files_changed'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  int get totalComments => comments.fold(0, (sum, c) => sum + c.count);

  List<String> get commenterLogins =>
      comments.map((c) => c.author.login).toList();

  List<String> get reviewerLogins =>
      approvals.map((a) => a.reviewer.login).toList();

  bool get isOpen => status == 'pending' || status == 'approved';

  bool get isMerged => status == 'merged';

  /// Extracts the 'owner/repo' name from the PR URL.
  String get repoName {
    try {
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      if (uri.host == 'api.github.com' &&
          parts.length >= 4 &&
          parts[0] == 'repos') {
        return '${parts[1]}/${parts[2]}';
      } else if (uri.host == 'github.com' && parts.length >= 2) {
        return '${parts[0]}/${parts[1]}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}

/// Timeline event types for a PR.
enum PrTimelineEventType { created, commented, approved, merged, closed }

extension PrTimelineExtension on PrEntity {
  /// Chronological list of important PR milestones:
  /// creation, comments (first/last per author), approvals, merged/closed.
  List<PrTimelineEvent> get timeline {
    final events = <PrTimelineEvent>[];

    // PR created
    events.add(
      PrTimelineEvent(
        type: PrTimelineEventType.created,
        at: openedAt,
        actor: creator,
        description: 'PR created',
      ),
    );

    // Approvals (who approved and when)
    for (final approval in approvals) {
      events.add(
        PrTimelineEvent(
          type: PrTimelineEventType.approved,
          at: approval.submittedAt,
          actor: approval.reviewer,
          description: 'Approved (commit ${approval.commitId})',
        ),
      );
    }

    // Comment milestones per participant (first / last)
    for (final c in comments) {
      if (c.firstCommentAt != null) {
        events.add(
          PrTimelineEvent(
            type: PrTimelineEventType.commented,
            at: c.firstCommentAt!,
            actor: c.author,
            description: 'First comment (${c.count} total)',
          ),
        );
      }
      if (c.lastCommentAt != null && c.lastCommentAt != c.firstCommentAt) {
        events.add(
          PrTimelineEvent(
            type: PrTimelineEventType.commented,
            at: c.lastCommentAt!,
            actor: c.author,
            description: 'Last comment',
          ),
        );
      }
    }

    // Merged / closed
    if (mergedAt != null && mergedBy != null) {
      events.add(
        PrTimelineEvent(
          type: PrTimelineEventType.merged,
          at: mergedAt!,
          actor: mergedBy!,
          description: 'PR merged',
        ),
      );
    } else if (closedAt != null) {
      events.add(
        PrTimelineEvent(
          type: PrTimelineEventType.closed,
          at: closedAt!,
          actor: creator,
          description: 'PR closed',
        ),
      );
    }

    events.sort((a, b) => a.at.compareTo(b.at));
    return events;
  }

  /// Unique list of all participants (creator, assignees, reviewers, commenters, merger).
  List<UserEntity> get participants {
    final Map<int, UserEntity> byId = {};

    void add(UserEntity u) {
      byId[u.id] = u;
    }

    add(creator);
    for (final a in assignees) {
      add(a);
    }
    for (final a in approvals) {
      add(a.reviewer);
    }
    for (final c in comments) {
      add(c.author);
    }
    if (mergedBy != null) {
      add(mergedBy!);
    }

    return byId.values.toList();
  }
}
