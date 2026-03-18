/// Live Meet Events View — Real-time event feed via SSE.
///
/// Shows a live scrolling feed of Google Meet events (joins, leaves,
/// meeting starts/ends) with status indicators and auto-scroll.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/meet_event_entity.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meet_events_provider.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';

class LiveEventsView extends StatefulWidget {
  const LiveEventsView({super.key});

  @override
  State<LiveEventsView> createState() => _LiveEventsViewState();
}

class _LiveEventsViewState extends State<LiveEventsView>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MeetEventsProvider>();
      provider.loadEvents();
      provider.startStreaming();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetEventsProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, provider),
            const SizedBox(height: AppSpacing.lg),
            _buildSubscribeSection(context, provider),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _buildEventFeed(context, provider)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MeetEventsProvider provider) {
    final scheme = context.colors;

    return Row(
      children: [
        // Live indicator
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: provider.isStreaming
                ? SellioColors.green.withValues(alpha: 0.15)
                : scheme.surface,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: provider.isStreaming
                  ? SellioColors.green.withValues(alpha: 0.4)
                  : scheme.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(isActive: provider.isStreaming),
              const SizedBox(width: AppSpacing.sm),
              Text(
                provider.isStreaming ? 'LIVE' : 'OFFLINE',
                style: AppTypography.caption.copyWith(
                  color: provider.isStreaming ? SellioColors.green : scheme.hint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Live Events',
          style: AppTypography.title.copyWith(
            color: scheme.title,
            fontSize: 20,
          ),
        ),
        const Spacer(),
        // Event count badge
        SBadge(
          label: '${provider.events.length} events',
          variant: SBadgeVariant.secondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        // Toggle streaming button
        SButton(
          variant: provider.isStreaming
              ? SButtonVariant.ghost
              : SButtonVariant.primary,
          onPressed: () {
            if (provider.isStreaming) {
              provider.stopStreaming();
            } else {
              provider.startStreaming();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                provider.isStreaming ? LucideIcons.pause : LucideIcons.play,
                size: 14,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(provider.isStreaming ? 'Pause' : 'Resume'),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SButton(
          variant: SButtonVariant.ghost,
          onPressed: provider.events.isEmpty
              ? null
              : () => provider.clearEvents(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.trash2, size: 14),
              SizedBox(width: AppSpacing.xs),
              Text('Clear'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscribeSection(
      BuildContext context, MeetEventsProvider provider) {
    final scheme = context.colors;
    final meetingsProvider = context.watch<MeetingsProvider>();
    final meetings = meetingsProvider.meetings;

    if (meetings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.stroke),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16, color: scheme.hint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Create a meeting first, then subscribe to track events in real-time.',
                style: AppTypography.body.copyWith(color: scheme.hint),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscribe to Meeting Events',
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Select a meeting to start receiving real-time participant join/leave notifications:',
            style: AppTypography.caption.copyWith(color: scheme.hint),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: meetings.map((meeting) {
              return SButton(
                variant: SButtonVariant.ghost,
                onPressed: provider.isSubscribing
                    ? null
                    : () => _subscribeToMeeting(provider, meeting.spaceName,
                        meeting.title),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.bell, size: 14),
                    const SizedBox(width: AppSpacing.xs),
                    Text(meeting.title),
                  ],
                ),
              );
            }).toList(),
          ),
          if (provider.isSubscribing) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (provider.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              provider.error!,
              style: AppTypography.caption.copyWith(color: SellioColors.red),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _subscribeToMeeting(
    MeetEventsProvider provider,
    String spaceName,
    String title,
  ) async {
    final success = await provider.subscribeToSpace(spaceName);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscribed to "$title" events!'),
          backgroundColor: SellioColors.green,
        ),
      );
    }
  }

  Widget _buildEventFeed(BuildContext context, MeetEventsProvider provider) {
    final scheme = context.colors;

    if (provider.isLoading && provider.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.radio,
              size: 64,
              color: scheme.hint.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No events yet',
              style: AppTypography.title.copyWith(
                color: scheme.hint,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Events will appear here in real-time when\nparticipants join or leave your meetings.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: scheme.hint.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: provider.events.length,
      itemBuilder: (context, index) {
        final event = provider.events[index];
        final isNew = index == 0;
        return _EventCard(event: event, isNew: isNew);
      },
    );
  }
}

// ─── Event Card ─────────────────────────────────────────────

class _EventCard extends StatefulWidget {
  final MeetEventEntity event;
  final bool isNew;

  const _EventCard({required this.event, this.isNew = false});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final event = widget.event;
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('MMM d');

    final isPositive = event.isJoinOrStart;
    final eventColor = isPositive ? SellioColors.green : SellioColors.red;
    final iconData = _getEventIcon(event.eventType);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: widget.isNew
                  ? eventColor.withValues(alpha: 0.4)
                  : scheme.stroke,
            ),
            boxShadow: widget.isNew
                ? [
                    BoxShadow(
                      color: eventColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Event type indicator with icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: eventColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(iconData, color: eventColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),

              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          event.shortType,
                          style: AppTypography.subtitle.copyWith(
                            color: eventColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (event.participantInfo != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '— ${event.participantInfo!.displayName}',
                            style: AppTypography.body.copyWith(
                              color: scheme.title,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (event.spaceName.isNotEmpty) ...[
                          Icon(LucideIcons.video, size: 12, color: scheme.hint),
                          const SizedBox(width: 4),
                          Text(
                            event.spaceName,
                            style: AppTypography.caption.copyWith(
                              color: scheme.hint,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        if (event.participantInfo?.email.isNotEmpty ??
                            false) ...[
                          Icon(LucideIcons.mail, size: 12, color: scheme.hint),
                          const SizedBox(width: 4),
                          Text(
                            event.participantInfo!.email,
                            style: AppTypography.caption.copyWith(
                              color: scheme.hint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Timestamp
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeFormat.format(event.timestamp.toLocal()),
                    style: AppTypography.caption.copyWith(
                      color: scheme.title,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    dateFormat.format(event.timestamp.toLocal()),
                    style: AppTypography.caption.copyWith(
                      color: scheme.hint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getEventIcon(String eventType) {
    if (eventType.contains('joined')) return LucideIcons.userPlus;
    if (eventType.contains('left')) return LucideIcons.userMinus;
    if (eventType.contains('started')) return LucideIcons.play;
    if (eventType.contains('ended')) return LucideIcons.square;
    return LucideIcons.activity;
  }
}

// ─── Pulsing Dot Indicator ──────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final bool isActive;
  const _PulsingDot({required this.isActive});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: context.colors.hint,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: SellioColors.green
                .withValues(alpha: 0.6 + 0.4 * _controller.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SellioColors.green
                    .withValues(alpha: 0.3 * _controller.value),
                blurRadius: 6,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
