/// Sellio Design System — SButton
///
/// Wrapper around HuxButton that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Button variant mirroring HuxButtonVariant.
enum SButtonVariant { primary, ghost }

/// Button size mirroring HuxButtonSize.
enum SButtonSize { small, medium, large }

HuxButtonVariant _toHuxVariant(SButtonVariant v) => switch (v) {
      SButtonVariant.primary => HuxButtonVariant.primary,
      SButtonVariant.ghost => HuxButtonVariant.ghost,
    };

HuxButtonSize _toHuxSize(SButtonSize s) => switch (s) {
      SButtonSize.small => HuxButtonSize.small,
      SButtonSize.medium => HuxButtonSize.medium,
      SButtonSize.large => HuxButtonSize.large,
    };

/// Sellio button component.
class SButton extends HuxButton {
  SButton({
    super.key,
    required super.child,
    super.onPressed,
    SButtonVariant variant = SButtonVariant.primary,
    SButtonSize size = SButtonSize.medium,
  }) : super(
          variant: _toHuxVariant(variant),
          size: _toHuxSize(size),
        );
}
