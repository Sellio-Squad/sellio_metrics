import 'package:hux/hux.dart';

enum SButtonVariant { primary, ghost, outline }

enum SButtonSize { small, medium, large }

HuxButtonVariant _toHuxVariant(SButtonVariant v) => switch (v) {
  SButtonVariant.primary => HuxButtonVariant.primary,
  SButtonVariant.ghost   => HuxButtonVariant.ghost,
  SButtonVariant.outline => HuxButtonVariant.outline,
};

HuxButtonSize _toHuxSize(SButtonSize s) => switch (s) {
  SButtonSize.small  => HuxButtonSize.small,
  SButtonSize.medium => HuxButtonSize.medium,
  SButtonSize.large  => HuxButtonSize.large,
};

class SButton extends HuxButton {
  SButton({
    super.key,
    required super.child,
    super.onPressed,
    super.primaryColor,  // pass-through for custom colour (e.g. SellioColors.red)
    SButtonVariant variant = SButtonVariant.primary,
    SButtonSize size = SButtonSize.medium,
  }) : super(variant: _toHuxVariant(variant), size: _toHuxSize(size));
}
