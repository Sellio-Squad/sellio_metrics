/// Sellio Metrics — PR List Tile Widget
///
/// Clickable, hoverable PR tile with type badge.
/// Follows SRP — only responsible for rendering a single PR entry.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/pr_entity.dart';
import '../../../domain/enums/pr_type.dart';
import '../../extensions/pr_type_presentation.dart';

class PrListTile extends StatefulWidget {
  final PrEntity pr;

  const PrListTile({super.key, required this.pr});

  @override
  State<PrListTile> createState() => _PrListTileState();
}

class _PrListTileState extends State<PrListTile> {
  bool _isHovered = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pr = widget.pr;
    final prType = PrType.fromTitle(pr.title);
    final scheme = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _openPrUrl,
        child: AnimatedContainer(
          duration: AnimationConstants.hoverDuration,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          transform: _isHovered
              ? (Matrix4.identity()..scaleByDouble(AnimationConstants.hoverScale, AnimationConstants.hoverScale, 1.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: scheme.surfaceLow,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _isHovered
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.stroke,
            ),
            boxShadow: _isHovered
                ? [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SAvatar(
                    name: pr.creator.login,
                    imageUrl: pr.creator.avatarUrl.isNotEmpty ? pr.creator.avatarUrl : null,
                    size: SAvatarSize.small,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pr.title,
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.title,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _InfoChip(text: '#${pr.prNumber}'),
                            if (pr.repoName.isNotEmpty)
                              _InfoChip(
                                  text: pr.repoName, icon: Icons.source_outlined),
                            _InfoChip(
                                text: pr.creator.login, icon: Icons.person_outline),
                            _InfoChip(
                                text: formatRelativeTime(pr.openedAt),
                                icon: Icons.schedule),
                            _DiffStatsChip(
                              additions: pr.diffStats.additions,
                              deletions: pr.diffStats.deletions,
                              changedFiles: pr.diffStats.changedFiles,
                            ),
                            _InfoChip(
                              text: '${pr.approvals.length} / ${pr.requiredApprovals} approvals',
                              icon: Icons.check_circle_outline,
                            ),
                            if (pr.firstApprovedAt != null)
                              _InfoChip(
                                text: '1st approval ${formatRelativeTime(pr.firstApprovedAt!)}',
                                icon: Icons.thumb_up_alt_outlined,
                              ),
                            if (pr.requiredApprovalsMetAt != null)
                              _InfoChip(
                                text: 'All approvals ${formatRelativeTime(pr.requiredApprovalsMetAt!)}',
                                icon: Icons.done_all_outlined,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Simple inline "timeline" summary (created → approvals → merged/closed)
                        _PrTimelineSummary(pr: pr),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _PrTypeBadge(prType: prType),
                      const SizedBox(height: AppSpacing.xs),
                      SBadge(
                        label: pr.status.toUpperCase(),
                        variant: _getBadgeVariant(pr.status),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: AnimationConstants.hoverDuration,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: scheme.hint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                _PrExpandedDetails(pr: pr),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openPrUrl() {
    final uri = Uri.tryParse(widget.pr.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  SBadgeVariant _getBadgeVariant(String status) {
    return switch (status) {
      PrStatus.merged => SBadgeVariant.primary,
      PrStatus.closed => SBadgeVariant.error,
      PrStatus.approved => SBadgeVariant.success,
      _ => SBadgeVariant.secondary,
    };
  }
}

/// Expanded section with Timeline, Participants, and Key Metrics.
class _PrExpandedDetails extends StatelessWidget {
  final PrEntity pr;

  const _PrExpandedDetails({required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Expanded(
            flex: 2,
            child: _DetailsGroup(
              title: 'Timeline',
              icon: Icons.timeline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pr.timeline.map((event) {
                  final label = switch (event.type) {
                    PrTimelineEventType.created => 'Created',
                    PrTimelineEventType.commented => 'Commented',
                    PrTimelineEventType.approved => 'Approved',
                    PrTimelineEventType.merged => 'Merged',
                    PrTimelineEventType.closed => 'Closed',
                  };

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            if (event != pr.timeline.last)
                              Container(
                                width: 2,
                                height: 24,
                                margin: const EdgeInsets.only(top: 2),
                                color: scheme.stroke,
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$label · ${event.actor.login}',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.title,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatRelativeTime(event.at),
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                  fontSize: 11,
                                ),
                              ),
                              if (event.description != null)
                                Text(
                                  event.description!,
                                  style: AppTypography.caption.copyWith(
                                    color: scheme.body,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Participants
          Expanded(
            flex: 2,
            child: _DetailsGroup(
              title: 'Participants',
              icon: Icons.group_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ParticipantsRow(
                    label: 'Assignees',
                    users: pr.assignees,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ParticipantsRow(
                    label: 'Approvers',
                    users: pr.approvals.map((a) => a.reviewer).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ParticipantsRow(
                    label: 'Commenters',
                    users: pr.comments.map((c) => c.author).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Key metrics
          Expanded(
            flex: 2,
            child: _DetailsGroup(
              title: 'Key Metrics',
              icon: Icons.insights_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricRow(
                    icon: Icons.access_time,
                    label: 'Time to 1st Approval',
                    value: formatDetailedDuration(pr.timeToFirstApprovalMinutes),
                  ),
                  _MetricRow(
                    icon: Icons.timelapse_outlined,
                    label: '1st → 2nd Approval',
                    value:
                        formatDetailedDuration(_timeFirstToSecondApprovalMinutes(pr)),
                  ),
                  _MetricRow(
                    icon: Icons.merge_type_outlined,
                    label: 'Time to Merge',
                    value: formatDetailedDuration(_timeToMergeMinutes(pr)),
                  ),
                  _MetricRow(
                    icon: Icons.chat_bubble_outline,
                    label: 'Total Comments',
                    value: pr.totalComments.toString(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _timeFirstToSecondApprovalMinutes(PrEntity pr) {
    if (pr.approvals.length < 2) return null;
    final approvals = [...pr.approvals]..sort(
          (a, b) => a.submittedAt.compareTo(b.submittedAt),
    );
    final first = approvals.first.submittedAt;
    final second = approvals[1].submittedAt;
    return second.difference(first).inMinutes.toDouble();
  }

  double? _timeToMergeMinutes(PrEntity pr) {
    if (pr.mergedAt == null) return null;
    return pr.mergedAt!.difference(pr.openedAt).inMinutes.toDouble();
  }
}

class _DetailsGroup extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData icon;

  const _DetailsGroup({
    required this.title,
    required this.child,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: scheme.hint,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                color: scheme.hint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _ParticipantsRow extends StatelessWidget {
  final String label;
  final List<UserEntity> users;

  const _ParticipantsRow({required this.label, required this.users});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    if (users.isEmpty) {
      return Text(
        '$label: No entries yet.',
        style: AppTypography.caption.copyWith(
          color: scheme.hint,
          fontSize: 11,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: users
              .map(
                (u) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SAvatar(
                  name: u.login,
                  imageUrl: u.avatarUrl.isNotEmpty ? u.avatarUrl : null,
                  size: SAvatarSize.small,
                ),
                const SizedBox(width: 4),
                Text(
                  u.login,
                  style: AppTypography.caption.copyWith(
                    color: scheme.body,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
              .toList(),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: scheme.hint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: scheme.body,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.caption.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact one-line summary of the PR timeline (created, approvals, merged/closed).
class _PrTimelineSummary extends StatelessWidget {
  final PrEntity pr;

  const _PrTimelineSummary({required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final parts = <String>[];
    parts.add('Opened ${formatRelativeTime(pr.openedAt)}');

    if (pr.firstApprovedAt != null) {
      parts.add('1st approval ${formatRelativeTime(pr.firstApprovedAt!)}');
    }

    if (pr.requiredApprovalsMetAt != null) {
      parts.add('All approvals ${formatRelativeTime(pr.requiredApprovalsMetAt!)}');
    }

    if (pr.mergedAt != null) {
      parts.add('Merged ${formatRelativeTime(pr.mergedAt!)}');
    } else if (pr.closedAt != null) {
      parts.add('Closed ${formatRelativeTime(pr.closedAt!)}');
    }

    final text = parts.join(' · ');

    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: scheme.hint,
        fontSize: 11,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Small info chip for PR metadata (author, date, diff stats).
class _InfoChip extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _InfoChip({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: scheme.hint),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Diff stats chip with colored additions and deletions, and files changed.
class _DiffStatsChip extends StatelessWidget {
  final int additions;
  final int deletions;
  final int changedFiles;

  const _DiffStatsChip({
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.code, size: 12, color: scheme.hint),
        const SizedBox(width: 3),
        Text(
          '+$additions',
          style: AppTypography.caption.copyWith(
            color: scheme.green,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        Text(
          ' / ',
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontSize: 11,
          ),
        ),
        Text(
          '-$deletions',
          style: AppTypography.caption.copyWith(
            color: scheme.red,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        Text(
          ' ($changedFiles files)',
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// PR type badge (Feature, Fix, Refactor, etc.).
class _PrTypeBadge extends StatelessWidget {
  final PrType prType;

  const _PrTypeBadge({required this.prType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: prType.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        prType.label,
        style: AppTypography.caption.copyWith(
          color: prType.color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
