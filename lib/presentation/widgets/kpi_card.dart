/// Sellio Metrics — KPI Card Widget
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/theme/app_theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? const Color(0xFF1E1E2E)
        : Colors.white;

    return HuxCard(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.1 : 0.05),
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
            Text(
              value,
              style: AppTypography.kpiValue.copyWith(
                color: isDark ? Colors.white : const Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? Colors.white70
                    : const Color(0xFF6B7280),
              ),
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
      ),
    );
  }
}
