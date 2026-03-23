
import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/utils/formatters.dart';
import 'package:sellio_metrics/core/utils/date_utils.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/entities/user_entity.dart';

class PrExpandedDetails extends StatelessWidget {
  final PrEntity pr;

  const PrExpandedDetails({super.key, required this.pr});

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _TimelineSection(pr: pr)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: _ParticipantsSection(pr: pr)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: _MetricsSection(pr: pr)),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimelineSection(pr: pr),
              const SizedBox(height: AppSpacing.lg),
              _ParticipantsSection(pr: pr),
              const SizedBox(height: AppSpacing.lg),
              _MetricsSection(pr: pr),
            ],
          );
        },
      ),
    );
  }
}

// ─── Timeline ────────────────────────────────────────────────

class _TimelineSection extends StatelessWidget {
  final PrEntity pr;

  const _TimelineSection({required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return _DetailsGroup(
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
    );
  }
}

// ─── Participants ────────────────────────────────────────────

class _ParticipantsSection extends StatelessWidget {
  final PrEntity pr;

  const _ParticipantsSection({required this.pr});

  @override
  Widget build(BuildContext context) {
    return _DetailsGroup(
      title: 'Participants',
      icon: Icons.group_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParticipantsRow(label: 'Assignees', users: pr.assignees),
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
    );
  }
}

// ─── Key Metrics ─────────────────────────────────────────────

class _MetricsSection extends StatelessWidget {
  final PrEntity pr;

  const _MetricsSection({required this.pr});

  @override
  Widget build(BuildContext context) {
    return _DetailsGroup(
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
            value: formatDetailedDuration(_firstToSecondMinutes()),
          ),
          _MetricRow(
            icon: Icons.merge_type_outlined,
            label: 'Time to Merge',
            value: formatDetailedDuration(_timeToMergeMinutes()),
          ),
          _MetricRow(
            icon: Icons.chat_bubble_outline,
            label: 'Total Comments',
            value: pr.totalComments.toString(),
          ),
        ],
      ),
    );
  }

  double? _firstToSecondMinutes() {
    if (pr.approvals.length < 2) return null;
    final sorted = [...pr.approvals]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return sorted[1]
        .submittedAt
        .difference(sorted.first.submittedAt)
        .inMinutes
        .toDouble();
  }

  double? _timeToMergeMinutes() {
    if (pr.mergedAt == null) return null;
    return pr.mergedAt!.difference(pr.openedAt).inMinutes.toDouble();
  }
}

// ─── Shared Building Blocks ──────────────────────────────────

class _DetailsGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailsGroup({
    required this.title,
    required this.icon,
    required this.child,
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
            Icon(icon, size: 16, color: scheme.hint),
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
                      imageUrl:
                          u.avatarUrl.isNotEmpty ? u.avatarUrl : null,
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
  final IconData icon;
  final String label;
  final String value;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.hint),
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
