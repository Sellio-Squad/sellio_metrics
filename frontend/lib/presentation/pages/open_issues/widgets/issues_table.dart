import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/issue_entity.dart';
import 'package:sellio_metrics/presentation/pages/open_issues/widgets/issue_status_badge.dart';

class IssuesTable extends StatelessWidget {
  final List<IssueEntity> issues;

  const IssuesTable({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return _EmptyState();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return isDesktop
        ? _DesktopTable(issues: issues)
        : _MobileCards(issues: issues);
  }
}

// ─── Empty State ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle, size: 48, color: scheme.green),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No issues match your filters',
              style: AppTypography.subtitle.copyWith(color: scheme.title),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try adjusting or clearing your filters.',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop Table ───────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<IssueEntity> issues;
  const _DesktopTable({required this.issues});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Column(
          children: [
            _TableHeader(),
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: issues.length,
              separatorBuilder: (_, __) => Divider(color: scheme.stroke, height: 1),
              itemBuilder: (_, i) => _DesktopRow(issue: issues[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          const SizedBox(width: 12), // status dot
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 4, child: _HeaderCell('Title')),
          Expanded(flex: 2, child: _HeaderCell('Repository')),
          Expanded(flex: 2, child: _HeaderCell('Author')),
          Expanded(flex: 2, child: _HeaderCell('Assignees')),
          Expanded(flex: 2, child: _HeaderCell('Deadline')),
          Expanded(flex: 2, child: _HeaderCell('Status')),
          const SizedBox(width: 40), // actions
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTypography.overline.copyWith(color: context.colors.hint),
      );
}

class _DesktopRow extends StatefulWidget {
  final IssueEntity issue;
  const _DesktopRow({required this.issue});

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final issue = widget.issue;

    final rowBg = switch (issue.healthStatus) {
      IssueHealthStatus.overdue => scheme.red.withValues(alpha: 0.04),
      IssueHealthStatus.noDeadline => const Color(0xFFF5A623).withValues(alpha: 0.04),
      IssueHealthStatus.healthy => Colors.transparent,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: rowBg,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  IssueStatusBadge(status: issue.healthStatus, compact: true),
                  const SizedBox(width: AppSpacing.md),
                  // Title + Labels
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.title,
                          style: AppTypography.body.copyWith(
                            color: scheme.title,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (issue.labels.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: issue.labels.take(3).map((l) => _LabelChip(label: l)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Repo
                  Expanded(
                    flex: 2,
                    child: Text(
                      issue.repoName,
                      style: AppTypography.caption.copyWith(color: scheme.body),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Author
                  Expanded(
                    flex: 2,
                    child: _UserChip(login: issue.author.login, avatarUrl: issue.author.avatarUrl),
                  ),
                  // Assignees
                  Expanded(
                    flex: 2,
                    child: issue.isUnassigned
                        ? Text(
                            'Unassigned',
                            style: AppTypography.caption.copyWith(color: scheme.hint),
                          )
                        : Wrap(
                            spacing: 4,
                            children: issue.assignees.take(2).map((a) => _AvatarBubble(login: a.login, avatarUrl: a.avatarUrl)).toList(),
                          ),
                  ),
                  // Deadline
                  Expanded(
                    flex: 2,
                    child: _DeadlineCell(issue: issue),
                  ),
                  // Status badge
                  Expanded(
                    flex: 2,
                    child: IssueStatusBadge(status: issue.healthStatus),
                  ),
                  // Actions
                  SizedBox(
                    width: 40,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _expanded ? LucideIcons.chevronsUpDown : LucideIcons.externalLink,
                            size: 14,
                            color: scheme.hint,
                          ),
                          onPressed: _expanded
                              ? () => setState(() => _expanded = false)
                              : () => _openInBrowser(issue.htmlUrl),
                          tooltip: _expanded ? 'Collapse' : 'Open in GitHub',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable details
          if (_expanded)
            _ExpandedDetails(issue: issue),
        ],
      ),
    );
  }

  void _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri);
  }
}

class _DeadlineCell extends StatelessWidget {
  final IssueEntity issue;
  const _DeadlineCell({required this.issue});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (!issue.hasDeadline) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: const Color(0xFFF5A623)),
          const SizedBox(width: 4),
          Text('No deadline', style: AppTypography.caption.copyWith(color: const Color(0xFFF5A623))),
        ],
      );
    }

    final daysLeft = issue.daysUntilDeadline!;
    final fmt = DateFormat('MMM d, yyyy');
    final dateStr = fmt.format(issue.milestone!.dueOn!);
    final color = issue.isOverdue ? scheme.red : scheme.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateStr, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        Text(
          issue.isOverdue ? '${daysLeft.abs()}d overdue' : 'in ${daysLeft}d',
          style: AppTypography.overline.copyWith(color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  final IssueEntity issue;
  const _ExpandedDetails({required this.issue});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.stroke)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Body
              if (issue.body.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description', style: AppTypography.overline.copyWith(color: scheme.hint)),
                      const SizedBox(height: 4),
                      Text(
                        issue.body.length > 400 ? '${issue.body.substring(0, 400)}…' : issue.body,
                        style: AppTypography.body.copyWith(color: scheme.body),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: AppSpacing.xl),
              // Meta
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaRow(label: 'Issue #', value: '${issue.number}'),
                    _MetaRow(label: 'Opened', value: DateFormat('MMM d, yyyy').format(issue.createdAt)),
                    if (issue.milestone != null)
                      _MetaRow(label: 'Milestone', value: issue.milestone!.title),
                    if (issue.priority != null)
                      _MetaRow(label: 'Priority', value: issue.priority!),
                    _MetaRow(label: 'Repo', value: issue.repoName),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Quick action
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(issue.htmlUrl);
                  if (uri != null) await launchUrl(uri);
                },
                icon: Icon(LucideIcons.externalLink, size: 14, color: scheme.primary),
                label: Text(
                  'Open in GitHub',
                  style: AppTypography.caption.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTypography.overline.copyWith(color: scheme.hint)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(color: scheme.title, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile Cards ────────────────────────────────────────────

class _MobileCards extends StatelessWidget {
  final List<IssueEntity> issues;
  const _MobileCards({required this.issues});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _MobileCard(issue: issues[i]),
    );
  }
}

class _MobileCard extends StatefulWidget {
  final IssueEntity issue;
  const _MobileCard({required this.issue});

  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final issue = widget.issue;

    final (statusColor) = switch (issue.healthStatus) {
      IssueHealthStatus.overdue => scheme.red,
      IssueHealthStatus.noDeadline => const Color(0xFFF5A623),
      IssueHealthStatus.healthy => scheme.green,
    };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IssueStatusBadge(status: issue.healthStatus),
                      const Spacer(),
                      Text(
                        issue.repoName,
                        style: AppTypography.caption.copyWith(color: scheme.hint),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    issue.title,
                    style: AppTypography.subtitle.copyWith(color: scheme.title),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _UserChip(login: issue.author.login, avatarUrl: issue.author.avatarUrl),
                      const SizedBox(width: AppSpacing.md),
                      _DeadlineCell(issue: issue),
                    ],
                  ),
                  if (issue.labels.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: issue.labels.take(4).map((l) => _LabelChip(label: l)).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded)
            _ExpandedDetails(issue: issue),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final IssueLabelEntity label;
  const _LabelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    Color bg;
    try {
      final hex = label.color.padLeft(6, '0');
      bg = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      bg = const Color(0xFFCCCCCC);
    }
    final luminance = bg.computeLuminance();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.name,
        style: AppTypography.overline.copyWith(
          color: luminance > 0.4 ? bg.withValues(alpha: 0.9) : bg,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  final String login;
  final String avatarUrl;
  const _UserChip({required this.login, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SAvatar(
          size: SAvatarSize.small,
          imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
          name: login,
        ),
        const SizedBox(width: 4),
        Text(login, style: AppTypography.caption.copyWith(color: scheme.body)),
      ],
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String login;
  final String avatarUrl;
  const _AvatarBubble({required this.login, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: login,
      child: SAvatar(
        size: SAvatarSize.small,
        imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        name: login,
      ),
    );
  }
}
