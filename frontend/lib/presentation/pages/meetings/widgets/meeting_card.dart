// ─── Widget: Meeting Card ─────────────────────────────────────────────────────
//
// Card shown in the main meetings grid. Displays meeting title, creation time,
// participant count, meeting code, and quick-action buttons.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/meeting_entity.dart';

class MeetingCard extends StatefulWidget {
  final MeetingEntity meeting;
  final VoidCallback onTap;

  const MeetingCard({super.key, required this.meeting, required this.onTap});

  @override
  State<MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends State<MeetingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final formatter = DateFormat('MMM d, h:mm a');
    final isRecent =
        DateTime.now().difference(widget.meeting.createdAt).inHours < 2;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _isHovered
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.stroke,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? scheme.primary.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Gradient accent line
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: isRecent
                        ? [
                            SellioColors.green,
                            SellioColors.green.withValues(alpha: 0.4)
                          ]
                        : [
                            scheme.primary,
                            scheme.primary.withValues(alpha: 0.3)
                          ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Title + status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.meeting.title,
                              style: AppTypography.title.copyWith(
                                color: scheme.title,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!widget.meeting.subscribed)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.xs),
                                  child: Tooltip(
                                    message: 'Real-time tracking unavailable',
                                    child: Icon(
                                      LucideIcons.wifiOff,
                                      size: 14,
                                      color: scheme.hint,
                                    ),
                                  ),
                                ),
                              if (isRecent) _LiveBadge(),
                            ],
                          ),
                        ],
                      ),

                      // ── Meta info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 13, color: scheme.hint),
                              const SizedBox(width: 4),
                              Text(
                                formatter.format(widget.meeting.createdAt),
                                style: AppTypography.caption
                                    .copyWith(color: scheme.hint),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              Icon(LucideIcons.users,
                                  size: 13, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.meeting.participantCount} ${l10n.participantsCount}',
                                style: AppTypography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.title,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Icon(LucideIcons.hash,
                                  size: 13, color: scheme.hint),
                              const SizedBox(width: 4),
                              Text(
                                widget.meeting.meetingCode,
                                style: AppTypography.caption
                                    .copyWith(color: scheme.hint),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // ── Actions
                      Row(
                        children: [
                          Expanded(
                            child: SButton(
                              variant: SButtonVariant.outline,
                              size: SButtonSize.small,
                              onPressed: widget.onTap,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.eye,
                                      size: 14, color: scheme.primary),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Text('Details'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: SButton(
                              variant: SButtonVariant.primary,
                              size: SButtonSize.small,
                              onPressed: () async {
                                final url =
                                    Uri.parse(widget.meeting.meetingUri);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(LucideIcons.video, size: 14),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(l10n.joinMeeting),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulsating Live Badge ─────────────────────────────────────────────────────

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: SellioColors.green
                .withValues(alpha: 0.1 + 0.05 * _controller.value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: SellioColors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SellioColors.green
                          .withValues(alpha: 0.4 * _controller.value),
                      blurRadius: 4 * _controller.value,
                      spreadRadius: 1 * _controller.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: AppTypography.caption.copyWith(
                  color: SellioColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
