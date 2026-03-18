library;

import 'package:flutter/material.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;

  /// The value display — accepts any widget.
  final Widget value;

  const KpiCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.value,
    this.subtitle,
  });

  /// Convenience constructor for plain text value.
  factory KpiCard.text({
    Key? key,
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    String? subtitle,
  }) {
    return KpiCard(
      key: key,
      label: label,
      icon: icon,
      accentColor: accentColor,
      subtitle: subtitle,
      value: _PlainValue(text: value),
    );
  }

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
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: AppSpacing.lg),
          value,
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: scheme.body),
          ),
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

class _PlainValue extends StatelessWidget {
  final String text;

  const _PlainValue({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Text(
      text,
      style: AppTypography.kpiValue.copyWith(color: scheme.title),
    );
  }
}