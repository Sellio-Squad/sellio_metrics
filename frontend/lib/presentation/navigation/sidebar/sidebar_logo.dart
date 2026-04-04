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
    return Image.asset(
      'assets/official_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }
}
