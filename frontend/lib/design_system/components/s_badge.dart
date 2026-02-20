/// Sellio Design System — SBadge
///
/// Wrapper around HuxBadge that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Badge variant mirroring HuxBadgeVariant.
enum SBadgeVariant {
  primary,
  secondary,
  success,
  error,
}

/// Maps [SBadgeVariant] to the underlying Hux variant.
HuxBadgeVariant _toHux(SBadgeVariant v) => switch (v) {
      SBadgeVariant.primary => HuxBadgeVariant.primary,
      SBadgeVariant.secondary => HuxBadgeVariant.secondary,
      SBadgeVariant.success => HuxBadgeVariant.success,
      SBadgeVariant.error => HuxBadgeVariant.error,
    };

/// Sellio badge component.
class SBadge extends HuxBadge {
  SBadge({
    super.key,
    required super.label,
    SBadgeVariant variant = SBadgeVariant.secondary,
  }) : super(variant: _toHux(variant));
}
