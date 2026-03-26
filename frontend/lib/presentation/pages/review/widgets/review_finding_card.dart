import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/review_entity.dart';

/// Scrollable list of findings for one category tab.
class FindingsList extends StatelessWidget {
  final List<ReviewFindingEntity> findings;
  final String emptyLabel;

  const FindingsList({
    super.key,
    required this.findings,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return _EmptyCategoryView(label: emptyLabel);
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: findings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => FindingCard(finding: findings[i]),
    );
  }
}

class _EmptyCategoryView extends StatelessWidget {
  final String label;
  const _EmptyCategoryView({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.checkCircle2, size: 40, color: scheme.green),
          const SizedBox(height: AppSpacing.md),
          Text(label,
              style: AppTypography.body.copyWith(
                  color: scheme.hint,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Expandable card for a single review finding.
class FindingCard extends StatefulWidget {
  final ReviewFindingEntity finding;
  const FindingCard({super.key, required this.finding});

  @override
  State<FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<FindingCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final f = widget.finding;
    final cfg = _severityConfig(f.severity, scheme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: scheme.shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header (tap to collapse) ─────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
                bottom: _expanded ? Radius.zero : Radius.circular(AppRadius.md)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                        color: cfg.color, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Severity chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: cfg.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cfg.icon, size: 10, color: cfg.color),
                                  const SizedBox(width: 3),
                                  Text(f.severity.label.toUpperCase(),
                                      style: AppTypography.overline.copyWith(
                                          color: cfg.color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _shortPath(f.file),
                                style: AppTypography.caption.copyWith(
                                    color: scheme.hint,
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (f.line != null)
                              Text(':${f.line}',
                                  style: AppTypography.caption.copyWith(
                                      color: scheme.hint,
                                      fontSize: 11,
                                      fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(f.title,
                            style: AppTypography.subtitle.copyWith(
                                color: scheme.title,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: scheme.hint,
                  ),
                ],
              ),
            ),
          ),

          // ─── Body (collapsible) ───────────────────────
          if (_expanded) ...[
            Divider(height: 1, color: scheme.stroke),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.description,
                      style: AppTypography.body
                          .copyWith(color: scheme.body, fontSize: 13, height: 1.6)),
                  if (f.suggestion != null && f.suggestion!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                            color: scheme.green.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.lightbulb, size: 14, color: scheme.green),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Suggestion',
                                    style: AppTypography.caption.copyWith(
                                        color: scheme.green,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(f.suggestion!,
                                    style: AppTypography.body.copyWith(
                                        color: scheme.body,
                                        fontSize: 13,
                                        height: 1.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shortPath(String path) {
    final parts = path.split('/');
    if (parts.length <= 3) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  ({Color color, IconData icon}) _severityConfig(
      ReviewSeverity severity, SellioColorScheme scheme) {
    switch (severity) {
      case ReviewSeverity.critical:
        return (color: scheme.red, icon: LucideIcons.alertOctagon);
      case ReviewSeverity.warning:
        return (color: scheme.secondary, icon: LucideIcons.alertTriangle);
      case ReviewSeverity.info:
        return (color: SellioColors.blue, icon: LucideIcons.info);
    }
  }
}
