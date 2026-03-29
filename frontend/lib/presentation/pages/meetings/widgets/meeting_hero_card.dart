// ─── Widget: Meeting Hero Card ────────────────────────────────────────────────
//
// Top section of MeetingDetailView showing title, metadata, and action buttons.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

class MeetingHeroCard extends StatelessWidget {
  final String title;
  final String meetingCode;
  final String createdAt;
  final String meetingUri;
  final bool isConnected;
  final bool meetingEnded;
  final bool isLoading;
  final VoidCallback onEndMeeting;

  const MeetingHeroCard({
    super.key,
    required this.title,
    required this.meetingCode,
    required this.createdAt,
    required this.meetingUri,
    required this.isConnected,
    required this.meetingEnded,
    required this.isLoading,
    required this.onEndMeeting,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Gradient accent line
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              gradient: LinearGradient(
                colors: isConnected
                    ? [SellioColors.green, SellioColors.green.withValues(alpha: 0.3)]
                    : meetingEnded
                        ? [SellioColors.red, SellioColors.red.withValues(alpha: 0.3)]
                        : [scheme.primary, scheme.primary.withValues(alpha: 0.3)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                final infoSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.title.copyWith(
                              fontSize: 24,
                              color: scheme.title,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (isConnected && !meetingEnded) ...[
                          const SizedBox(width: AppSpacing.md),
                          _ConnectionBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _MetaChip(icon: LucideIcons.calendar, text: createdAt),
                        _MetaChip(
                          icon: LucideIcons.hash,
                          text: meetingCode,
                          copyable: true,
                        ),
                      ],
                    ),
                  ],
                );

                final actionsSection = Row(
                  mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    if (!meetingEnded) ...[
                      SButton(
                        variant: SButtonVariant.primary,
                        onPressed: () async {
                          final url = Uri.parse(meetingUri);
                          if (await canLaunchUrl(url)) await launchUrl(url);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.video, size: 16),
                            const SizedBox(width: AppSpacing.sm),
                            Text(l10n.joinMeeting),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SButton(
                        variant: SButtonVariant.primary,
                        primaryColor: SellioColors.red,
                        onPressed: isLoading ? null : onEndMeeting,
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.squareSlash, size: 14),
                                  SizedBox(width: AppSpacing.xs),
                                  Text('End Meeting'),
                                ],
                              ),
                      ),
                    ],
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: infoSection),
                      actionsSection,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoSection,
                    const SizedBox(height: AppSpacing.lg),
                    actionsSection,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Connection Badge ────────────────────────────────────────────────────────

class _ConnectionBadge extends StatefulWidget {
  @override
  State<_ConnectionBadge> createState() => _ConnectionBadgeState();
}

class _ConnectionBadgeState extends State<_ConnectionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SellioColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: SellioColors.green.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: SellioColors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: SellioColors.green.withValues(alpha: 0.5 * _pulse.value),
                      blurRadius: 6 * _pulse.value,
                      spreadRadius: 2 * _pulse.value,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Connected',
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

// ─── Meta Chip ───────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool copyable;

  const _MetaChip({
    required this.icon,
    required this.text,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.hint),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.body.copyWith(color: scheme.hint, fontSize: 13),
        ),
        if (copyable) ...[
          const SizedBox(width: 4),
          Icon(LucideIcons.copy, size: 12, color: scheme.hint.withValues(alpha: 0.5)),
        ],
      ],
    );

    if (copyable) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Meeting code copied!'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
            );
          },
          child: content,
        ),
      );
    }

    return content;
  }
}
