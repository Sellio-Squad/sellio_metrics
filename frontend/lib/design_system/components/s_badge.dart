import 'package:hux/hux.dart';

enum SBadgeVariant { primary, secondary, success, error }

HuxBadgeVariant _toHux(SBadgeVariant v) => switch (v) {
  SBadgeVariant.primary => HuxBadgeVariant.primary,
  SBadgeVariant.secondary => HuxBadgeVariant.secondary,
  SBadgeVariant.success => HuxBadgeVariant.success,
  SBadgeVariant.error => HuxBadgeVariant.error,
};

class SBadge extends HuxBadge {
  SBadge({
    super.key,
    required super.label,
    SBadgeVariant variant = SBadgeVariant.secondary,
  }) : super(variant: _toHux(variant));
}
