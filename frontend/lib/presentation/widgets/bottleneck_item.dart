/// Sellio Metrics — Bottleneck Item Widget
///
/// Clickable, hoverable PR card for the "Slow PRs" section.
/// Follows SRP — only responsible for rendering a single bottleneck entry.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bottleneck_entity.dart';
import '../../l10n/app_localizations.dart';
import '../extensions/severity_presentation.dart';

class BottleneckItem extends StatefulWidget {
  final BottleneckEntity bottleneck;

  const BottleneckItem({super.key, required this.bottleneck});

  @override
  State<BottleneckItem> createState() => _BottleneckItemState();
}

class _BottleneckItemState extends State<BottleneckItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bottleneck;
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final severityColor = b.severity.color;

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
            children: [
              // Severity badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  b.severity.label,
                  style: AppTypography.caption.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // PR info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${b.prNumber} ${b.title}',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.title,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.author} · ${b.waitTimeDays.toStringAsFixed(1)} ${l10n.bottleneckWaiting}',
                      style: AppTypography.caption.copyWith(
                        color: scheme.body,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.open_in_new,
                size: LayoutConstants.iconSizeSm,
                color: _isHovered ? scheme.primary : scheme.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrUrl() {
    final uri = Uri.tryParse(widget.bottleneck.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
