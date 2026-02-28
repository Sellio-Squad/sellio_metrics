library;

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

  /// Extracts the 'owner/repo' name from the PR URL.
  String get repoName {
    try {
      final uri = Uri.parse(url);
      final parts = uri.pathSegments;
      if (uri.host == 'api.github.com' && parts.length >= 4 && parts[0] == 'repos') {
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

/// Single event in the PR timeline (used for "milestones").
class PrTimelineEvent {
  final PrTimelineEventType type;
  final DateTime at;
  final UserEntity actor;
  final String? description;

  const PrTimelineEvent({
    required this.type,
    required this.at,
    required this.actor,
    this.description,
  });
}

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
