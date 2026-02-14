/// Sellio Metrics — Bottleneck Item Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/bottleneck_entity.dart';
import '../../domain/enums/severity.dart';

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
    final severityColor = _getSeverityColor(widget.bottleneck.severity);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _openPrUrl(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.01))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: context.isDark
                ? SellioColors.darkSurface
                : SellioColors.lightSurface,
            borderRadius: AppRadius.mdAll,
            border: Border(
              left: BorderSide(color: severityColor, width: 3),
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: severityColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truncateText(widget.bottleneck.title, 60),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.isDark
                            ? Colors.white
                            : SellioColors.gray700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '#${widget.bottleneck.prNumber} by ${widget.bottleneck.author}',
                      style: AppTypography.caption.copyWith(
                        color: context.isDark
                            ? Colors.white54
                            : SellioColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  HuxBadge(
                    label: widget.bottleneck.severity.label,
                    variant: _getBadgeVariant(widget.bottleneck.severity),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${widget.bottleneck.waitTimeDays.toStringAsFixed(1)}d waiting',
                    style: AppTypography.caption.copyWith(
                      color: severityColor,
                      fontWeight: FontWeight.w600,
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

  void _openPrUrl() {
    final uri = Uri.tryParse(widget.bottleneck.url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _getSeverityColor(Severity severity) {
    return switch (severity) {
      Severity.high => SellioColors.severityHigh,
      Severity.medium => SellioColors.severityMedium,
      Severity.low => SellioColors.severityLow,
    };
  }

  HuxBadgeVariant _getBadgeVariant(Severity severity) {
    return switch (severity) {
      Severity.high => HuxBadgeVariant.error,
      Severity.medium => HuxBadgeVariant.secondary,
      Severity.low => HuxBadgeVariant.success,
    };
  }
}
