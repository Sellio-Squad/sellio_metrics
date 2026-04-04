import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/ticket_entity.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/widgets/ticket_status_badge.dart';

class TicketsTable extends StatelessWidget {
  final List<TicketEntity> tickets;

  const TicketsTable({super.key, required this.tickets});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return _EmptyState();
    final width = MediaQuery.sizeOf(context).width;
    return width >= 900
        ? _DesktopTable(tickets: tickets)
        : _MobileCards(tickets: tickets);
  }
}

// ─── Empty State ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.checkCircle, size: 48, color: scheme.green),
          const SizedBox(height: AppSpacing.lg),
          Text('No tickets match your filters',
            style: AppTypography.subtitle.copyWith(color: scheme.title)),
          const SizedBox(height: AppSpacing.sm),
          Text('Try adjusting or clearing your filters.',
            style: AppTypography.body.copyWith(color: scheme.hint)),
        ]),
      ),
    );
  }
}

// ─── Desktop Table ────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<TicketEntity> tickets;
  const _DesktopTable({required this.tickets});

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
        child: Column(children: [
          _TableHeader(),
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => Divider(color: scheme.stroke, height: 1),
            itemBuilder: (_, i) => _DesktopRow(ticket: tickets[i]),
          ),
        ]),
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
      child: Row(children: [
        const SizedBox(width: 12),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 4, child: _HCell('Title')),
        Expanded(flex: 2, child: _HCell('Repository')),
        Expanded(flex: 2, child: _HCell('Author')),
        Expanded(flex: 2, child: _HCell('Assignees')),
        Expanded(flex: 2, child: _HCell('Deadline')),
        Expanded(flex: 2, child: _HCell('Status')),
        Expanded(flex: 2, child: _HCell('Source')),
        const SizedBox(width: 40),
      ]),
    );
  }
}

class _HCell extends StatelessWidget {
  final String label;
  const _HCell(this.label);
  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTypography.overline.copyWith(color: context.colors.hint));
}

class _DesktopRow extends StatefulWidget {
  final TicketEntity ticket;
  const _DesktopRow({required this.ticket});
  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final t = widget.ticket;

    final rowBg = t.source == TicketSource.draft
        ? scheme.surfaceLow
        : switch (t.healthStatus) {
            TicketHealthStatus.overdue    => scheme.red.withValues(alpha: 0.04),
            TicketHealthStatus.noDeadline => const Color(0xFFF5A623).withValues(alpha: 0.03),
            TicketHealthStatus.healthy    => Colors.transparent,
          };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: rowBg,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(children: [
              TicketStatusBadge(status: t.healthStatus, source: t.source, compact: true),
              const SizedBox(width: AppSpacing.md),
              // Title + labels
              Expanded(flex: 4, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                    style: AppTypography.body.copyWith(color: scheme.title, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (t.labels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 4,
                      children: t.labels.take(3).map((l) => _LabelChip(label: l)).toList()),
                  ],
                ],
              )),
              // Repo
              Expanded(flex: 2, child: t.repoName.isNotEmpty
                ? Text(t.repoName,
                    style: AppTypography.caption.copyWith(color: scheme.body),
                    overflow: TextOverflow.ellipsis)
                : _ProjectLink(projectName: t.projectName)),
              // Author
              Expanded(flex: 2, child: t.source == TicketSource.draft
                ? Text('Draft', style: AppTypography.caption.copyWith(color: scheme.hint))
                : _UserChip(login: t.author.login, avatarUrl: t.author.avatarUrl)),
              // Assignees
              Expanded(flex: 2, child: t.isUnassigned
                ? Text('Unassigned', style: AppTypography.caption.copyWith(color: scheme.hint))
                : Wrap(spacing: 4,
                    children: t.assignees.take(2)
                        .map((a) => _AvatarBubble(login: a.login, avatarUrl: a.avatarUrl))
                        .toList())),
              // Deadline
              Expanded(flex: 2, child: _DeadlineCell(ticket: t)),
              // Health status
              Expanded(flex: 2, child: TicketStatusBadge(status: t.healthStatus, source: t.source)),
              // Source badge
              Expanded(flex: 2, child: _SourceBadge(source: t.source, projectName: t.projectName)),
              // Action
              SizedBox(width: 40, child: IconButton(
                icon: Icon(
                  _expanded ? LucideIcons.chevronsUpDown : LucideIcons.externalLink,
                  size: 14, color: scheme.hint),
                onPressed: _expanded
                    ? () => setState(() => _expanded = false)
                    : () => _open(t.htmlUrl),
                tooltip: _expanded ? 'Collapse' : 'Open in GitHub',
              )),
            ]),
          ),
        ),
        if (_expanded) _ExpandedDetails(ticket: t),
      ]),
    );
  }

  void _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri);
  }
}

// ─── Deadline Cell ────────────────────────────────────────────

class _DeadlineCell extends StatelessWidget {
  final TicketEntity ticket;
  const _DeadlineCell({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    if (!ticket.hasDeadline) {
      if (ticket.source == TicketSource.draft) {
        return Text('—', style: AppTypography.caption.copyWith(color: scheme.hint));
      }
      return Row(children: [
        Icon(Icons.warning_amber_rounded, size: 13, color: const Color(0xFFF5A623)),
        const SizedBox(width: 4),
        Text('No deadline', style: AppTypography.caption.copyWith(color: const Color(0xFFF5A623))),
      ]);
    }

    final color = ticket.isOverdue ? scheme.red : scheme.green;
    final fmt = DateFormat('MMM d, yyyy');
    final daysLeft = ticket.daysUntilDeadline!;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(fmt.format(ticket.effectiveDeadline!),
        style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      Text(ticket.isOverdue ? '${daysLeft.abs()}d overdue' : 'in ${daysLeft}d',
        style: AppTypography.overline.copyWith(color: color.withValues(alpha: 0.7))),
    ]);
  }
}

// ─── Source Badge ─────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final TicketSource source;
  final String? projectName;
  const _SourceBadge({required this.source, this.projectName});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final (Color bg, Color fg, String label) = switch (source) {
      TicketSource.issue       => (scheme.primaryVariant, scheme.primary, 'Issue'),
      TicketSource.projectItem => (const Color(0xFF8B5CF6).withValues(alpha: 0.12), const Color(0xFF8B5CF6), 'Project'),
      TicketSource.draft       => (scheme.stroke, scheme.hint, 'Draft'),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smAll),
        child: Text(label,
          style: AppTypography.overline.copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 10)),
      ),
      if (projectName != null) ...[
        const SizedBox(height: 2),
        Text(projectName!,
          style: AppTypography.overline.copyWith(color: scheme.hint, fontSize: 10),
          overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}

// ─── Expanded Details ─────────────────────────────────────────

class _ExpandedDetails extends StatelessWidget {
  final TicketEntity ticket;
  const _ExpandedDetails({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.stroke)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ticket.body.isNotEmpty)
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Description', style: AppTypography.overline.copyWith(color: scheme.hint)),
              const SizedBox(height: 4),
              Text(ticket.body.length > 400 ? '${ticket.body.substring(0, 400)}…' : ticket.body,
                style: AppTypography.body.copyWith(color: scheme.body)),
            ])),
          const SizedBox(width: AppSpacing.xl),
          SizedBox(width: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ticket.number > 0) _MetaRow(label: 'Issue #', value: '${ticket.number}'),
            _MetaRow(label: 'Opened', value: DateFormat('MMM d, yyyy').format(ticket.createdAt)),
            if (ticket.milestone != null) _MetaRow(label: 'Milestone', value: ticket.milestone!.title),
            if (ticket.projectName != null) _MetaRow(label: 'Project', value: ticket.projectName!),
            if (ticket.projectStatus != null) _MetaRow(label: 'Status', value: ticket.projectStatus!),
            if (ticket.priority != null) _MetaRow(label: 'Priority', value: ticket.priority!),
            if (ticket.repoName.isNotEmpty) _MetaRow(label: 'Repo', value: ticket.repoName),
          ])),
        ]),
        const SizedBox(height: AppSpacing.md),
        TextButton.icon(
          onPressed: () async {
            final uri = Uri.tryParse(ticket.htmlUrl);
            if (uri != null) await launchUrl(uri);
          },
          icon: Icon(LucideIcons.externalLink, size: 14, color: scheme.primary),
          label: Text('Open in GitHub',
            style: AppTypography.caption.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
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
      child: Row(children: [
        SizedBox(width: 80,
          child: Text(label, style: AppTypography.overline.copyWith(color: scheme.hint))),
        Expanded(child: Text(value,
          style: AppTypography.caption.copyWith(color: scheme.title, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ─── Mobile Cards ─────────────────────────────────────────────

class _MobileCards extends StatelessWidget {
  final List<TicketEntity> tickets;
  const _MobileCards({required this.tickets});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _MobileCard(ticket: tickets[i]),
    );
  }
}

class _MobileCard extends StatefulWidget {
  final TicketEntity ticket;
  const _MobileCard({required this.ticket});
  @override
  State<_MobileCard> createState() => _MobileCardState();
}

class _MobileCardState extends State<_MobileCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final t = widget.ticket;
    final borderColor = t.source == TicketSource.draft
        ? scheme.stroke
        : switch (t.healthStatus) {
            TicketHealthStatus.overdue    => scheme.red.withValues(alpha: 0.4),
            TicketHealthStatus.noDeadline => const Color(0xFFF5A623).withValues(alpha: 0.4),
            TicketHealthStatus.healthy    => scheme.green.withValues(alpha: 0.3),
          };

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                TicketStatusBadge(status: t.healthStatus, source: t.source),
                const SizedBox(width: AppSpacing.sm),
                _SourceBadge(source: t.source, projectName: null),
                const Spacer(),
                if (t.repoName.isNotEmpty)
                  Text(t.repoName, style: AppTypography.caption.copyWith(color: scheme.hint)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Text(t.title, style: AppTypography.subtitle.copyWith(color: scheme.title)),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                if (t.source != TicketSource.draft)
                  _UserChip(login: t.author.login, avatarUrl: t.author.avatarUrl),
                const SizedBox(width: AppSpacing.md),
                _DeadlineCell(ticket: t),
              ]),
              if (t.labels.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: 4, runSpacing: 4,
                  children: t.labels.take(4).map((l) => _LabelChip(label: l)).toList()),
              ],
            ]),
          ),
        ),
        if (_expanded) _ExpandedDetails(ticket: t),
      ]),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────

class _LabelChip extends StatelessWidget {
  final TicketLabelEntity label;
  const _LabelChip({required this.label});
  @override
  Widget build(BuildContext context) {
    Color bg;
    try {
      bg = Color(int.parse('FF${label.color.padLeft(6, '0')}', radix: 16));
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
      child: Text(label.name,
        style: AppTypography.overline.copyWith(
          color: luminance > 0.4 ? bg.withValues(alpha: 0.9) : bg, fontSize: 10)),
    );
  }
}

class _ProjectLink extends StatelessWidget {
  final String? projectName;
  const _ProjectLink({this.projectName});
  @override
  Widget build(BuildContext context) {
    if (projectName == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(LucideIcons.layoutList, size: 12, color: const Color(0xFF8B5CF6)),
      const SizedBox(width: 4),
      Flexible(child: Text(projectName!,
        style: AppTypography.caption.copyWith(color: const Color(0xFF8B5CF6)),
        overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _UserChip extends StatelessWidget {
  final String login;
  final String avatarUrl;
  const _UserChip({required this.login, required this.avatarUrl});
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SAvatar(size: SAvatarSize.small, imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null, name: login),
      const SizedBox(width: 4),
      Text(login, style: AppTypography.caption.copyWith(color: scheme.body)),
    ]);
  }
}

class _AvatarBubble extends StatelessWidget {
  final String login;
  final String avatarUrl;
  const _AvatarBubble({required this.login, required this.avatarUrl});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: login,
    child: SAvatar(size: SAvatarSize.small, imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null, name: login),
  );
}
