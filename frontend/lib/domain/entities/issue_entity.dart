import 'package:sellio_metrics/domain/entities/user_entity.dart';

// ─── Sub-entities ────────────────────────────────────────────

class IssueLabelEntity {
  final String name;
  final String color; // hex without #

  const IssueLabelEntity({required this.name, required this.color});
}

class IssueMilestoneEntity {
  final String title;
  final DateTime? dueOn;

  const IssueMilestoneEntity({required this.title, this.dueOn});
}

// ─── Health Status ───────────────────────────────────────────

enum IssueHealthStatus { healthy, noDeadline, overdue }

// ─── Main Entity ─────────────────────────────────────────────

class IssueEntity {
  final int number;
  final String title;
  final String url;
  final String htmlUrl;
  final String repoName;
  final UserEntity author;
  final List<UserEntity> assignees;
  final List<IssueLabelEntity> labels;
  final DateTime createdAt;
  final IssueMilestoneEntity? milestone;
  final String? priority;
  final String body;

  const IssueEntity({
    required this.number,
    required this.title,
    required this.url,
    required this.htmlUrl,
    required this.repoName,
    required this.author,
    required this.assignees,
    required this.labels,
    required this.createdAt,
    this.milestone,
    this.priority,
    this.body = '',
  });

  // ─── Computed ─────────────────────────────────────────────

  bool get hasDeadline => milestone?.dueOn != null;

  bool get isOverdue {
    if (!hasDeadline) return false;
    return milestone!.dueOn!.isBefore(DateTime.now());
  }

  bool get isUnassigned => assignees.isEmpty;

  IssueHealthStatus get healthStatus {
    if (isOverdue) return IssueHealthStatus.overdue;
    if (!hasDeadline) return IssueHealthStatus.noDeadline;
    return IssueHealthStatus.healthy;
  }

  /// Days until deadline (negative = overdue).
  int? get daysUntilDeadline {
    if (!hasDeadline) return null;
    return milestone!.dueOn!.difference(DateTime.now()).inDays;
  }

  factory IssueEntity.fromJson(Map<String, dynamic> json) {
    // Parse labels
    final rawLabels = json['labels'] as List<dynamic>? ?? [];
    final labels = rawLabels.map((l) {
      final map = l as Map<String, dynamic>;
      return IssueLabelEntity(
        name: map['name'] as String? ?? '',
        color: map['color'] as String? ?? 'cccccc',
      );
    }).toList();

    // Parse milestone
    final rawMilestone = json['milestone'] as Map<String, dynamic>?;
    final milestone = rawMilestone != null
        ? IssueMilestoneEntity(
            title: rawMilestone['title'] as String? ?? '',
            dueOn: rawMilestone['due_on'] != null
                ? DateTime.tryParse(rawMilestone['due_on'].toString())
                : null,
          )
        : null;

    // Parse author
    final rawAuthor = json['author'] as Map<String, dynamic>? ?? {};
    final author = UserEntity(
      id: 0,
      login: rawAuthor['login'] as String? ?? 'unknown',
      avatarUrl: rawAuthor['avatar_url'] as String? ?? '',
    );

    // Parse assignees
    final rawAssignees = json['assignees'] as List<dynamic>? ?? [];
    final assignees = rawAssignees.map((a) {
      final map = a as Map<String, dynamic>;
      return UserEntity(
        id: 0,
        login: map['login'] as String? ?? 'unknown',
        avatarUrl: map['avatar_url'] as String? ?? '',
      );
    }).toList();

    return IssueEntity(
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? 'Untitled Issue',
      url: json['url'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      repoName: json['repo_name'] as String? ?? '',
      author: author,
      assignees: assignees,
      labels: labels,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      milestone: milestone,
      priority: json['priority'] as String?,
      body: json['body'] as String? ?? '',
    );
  }
}
