import 'package:flutter/material.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

/// Reusable brand-mark logo used in the sidebar header and splash screen.
///
/// Accepts an optional [size] to support both collapsed (36×36) and
/// larger (64×64) contexts.
class SidebarLogo extends StatelessWidget {
  final double size;

  const SidebarLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).extension<SellioColorScheme>();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SellioColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          'S',
          style: TextStyle(
            color: scheme?.onPrimary ?? Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
