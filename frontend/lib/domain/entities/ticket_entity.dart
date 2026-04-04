import 'package:sellio_metrics/domain/entities/user_entity.dart';

// ─── Sub-entities ────────────────────────────────────────────

class TicketLabelEntity {
  final String name;
  final String color; // hex without #

  const TicketLabelEntity({required this.name, required this.color});
}

class TicketMilestoneEntity {
  final String title;
  final DateTime? dueOn;

  const TicketMilestoneEntity({required this.title, this.dueOn});
}

// ─── Source ──────────────────────────────────────────────────

enum TicketSource { issue, projectItem, draft }

// ─── Health Status ───────────────────────────────────────────

enum TicketHealthStatus { healthy, noDeadline, overdue }

// ─── Main Entity ─────────────────────────────────────────────

class TicketEntity {
  final int number;
  final String title;
  final String url;
  final String htmlUrl;
  final String repoName;
  final UserEntity author;
  final List<UserEntity> assignees;
  final List<TicketLabelEntity> labels;
  final DateTime createdAt;
  final TicketMilestoneEntity? milestone;
  final String? priority;
  final String body;
  // ── Source / Project enrichment ──────────────────────────
  final TicketSource source;
  final String? projectName;
  final int? projectNumber;
  final String? projectStatus;
  final DateTime? dueDate; // project-level date field (overrides milestone if present)

  const TicketEntity({
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
    this.source = TicketSource.issue,
    this.projectName,
    this.projectNumber,
    this.projectStatus,
    this.dueDate,
  });

  // ─── Computed ────────────────────────────────────────────

  /// Effective deadline: project due_date takes priority over milestone.dueOn
  DateTime? get effectiveDeadline => dueDate ?? milestone?.dueOn;

  bool get hasDeadline => effectiveDeadline != null;

  bool get isOverdue {
    if (!hasDeadline) return false;
    return effectiveDeadline!.isBefore(DateTime.now());
  }

  bool get isUnassigned => assignees.isEmpty;

  TicketHealthStatus get healthStatus {
    if (isOverdue) return TicketHealthStatus.overdue;
    if (!hasDeadline) return TicketHealthStatus.noDeadline;
    return TicketHealthStatus.healthy;
  }

  /// Days until deadline (negative = overdue).
  int? get daysUntilDeadline {
    if (!hasDeadline) return null;
    return effectiveDeadline!.difference(DateTime.now()).inDays;
  }

  factory TicketEntity.fromJson(Map<String, dynamic> json) {
    // Parse labels
    final rawLabels = json['labels'] as List<dynamic>? ?? [];
    final labels = rawLabels.map((l) {
      final map = l as Map<String, dynamic>;
      return TicketLabelEntity(
        name: map['name'] as String? ?? '',
        color: map['color'] as String? ?? 'cccccc',
      );
    }).toList();

    // Parse milestone
    final rawMilestone = json['milestone'] as Map<String, dynamic>?;
    final milestone = rawMilestone != null
        ? TicketMilestoneEntity(
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

    // Parse source
    final sourceStr = json['source'] as String? ?? 'issue';
    final source = switch (sourceStr) {
      'project_item' => TicketSource.projectItem,
      'draft'        => TicketSource.draft,
      _              => TicketSource.issue,
    };

    // Parse project due_date
    final dueDateStr = json['due_date'] as String?;
    final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;

    return TicketEntity(
      number:        json['number'] as int? ?? 0,
      title:         json['title'] as String? ?? 'Untitled Ticket',
      url:           json['url'] as String? ?? '',
      htmlUrl:       json['html_url'] as String? ?? '',
      repoName:      json['repo_name'] as String? ?? '',
      author:        author,
      assignees:     assignees,
      labels:        labels,
      createdAt:     DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      milestone:     milestone,
      priority:      json['priority'] as String?,
      body:          json['body'] as String? ?? '',
      source:        source,
      projectName:   json['project_name'] as String?,
      projectNumber: json['project_number'] as int?,
      projectStatus: json['project_status'] as String?,
      dueDate:       dueDate,
    );
  }
}
