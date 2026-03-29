// ─── Widget: KPI Row ──────────────────────────────────────────────────────────
//
// Three stat cards (Live Now, Total Attended, Avg Duration) shown in a row
// on wide screens, or stacked vertically on narrow screens.

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

class KpiRow extends StatelessWidget {
  final int activeCount;
  final int totalCount;
  final int averageDuration;

  const KpiRow({
    super.key,
    required this.activeCount,
    required this.totalCount,
    required this.averageDuration,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = AppSpacing.lg;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;

        final cards = [
          _KpiCard(
            label: 'Live Now',
            value: activeCount.toString(),
            icon: LucideIcons.radio,
            accentColor: activeCount > 0 ? SellioColors.green : null,
            showPulse: activeCount > 0,
          ),
          _KpiCard(
            label: 'Total Attended',
            value: totalCount.toString(),
            icon: LucideIcons.users,
          ),
          _KpiCard(
            label: 'Avg Duration',
            value: averageDuration < 1 ? '< 1 min' : '$averageDuration min',
            icon: LucideIcons.clock,
          ),
        ];

        if (isCompact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final bool showPulse;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.showPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = accentColor ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: AppTypography.title.copyWith(
                        fontSize: 26,
                        color: scheme.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (showPulse) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _PulsingDot(color: color),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing Dot ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

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
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * _controller.value),
                blurRadius: 6 * _controller.value,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
