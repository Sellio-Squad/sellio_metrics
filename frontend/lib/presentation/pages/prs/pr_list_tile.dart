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
          child: Row(
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
                        _InfoChip(
                            text: pr.creator.login, icon: Icons.person_outline),
                        _InfoChip(
                            text: formatRelativeTime(pr.openedAt),
                            icon: Icons.schedule),
                        _InfoChip(
                            text:
                                '+${pr.diffStats.additions} / -${pr.diffStats.deletions}',
                            icon: Icons.code),
                      ],
                    ),
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
                ],
              ),
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
