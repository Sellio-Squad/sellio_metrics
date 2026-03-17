library;

import 'package:flutter/material.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;

  /// Plain text value — used when no rich value is provided.
  final String? value;

  /// Rich value — replaces plain [value] with colored spans.
  final InlineSpan? richValue;

  const KpiCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.value,
    this.richValue,
    this.subtitle,
  }) : assert(
  value != null || richValue != null,
  'Either value or richValue must be provided',
  );

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(
              alpha: context.isDark ? 0.1 : 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Value — either plain or rich, never both
          if (richValue != null)
            Text.rich(
              TextSpan(children: [richValue!]),
              style: AppTypography.kpiValue,
            )
          else
            Text(
              value!,
              style: AppTypography.kpiValue.copyWith(color: scheme.title),
            ),

          const SizedBox(height: AppSpacing.xs),

          // Label
          Text(
            label,
            style: AppTypography.caption.copyWith(color: scheme.body),
          ),

          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(
                color: accentColor,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}