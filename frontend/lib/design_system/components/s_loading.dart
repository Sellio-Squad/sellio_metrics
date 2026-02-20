/// Sellio Design System — SLoading
///
/// Wrapper around HuxLoading that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Loading size mirroring HuxLoadingSize.
enum SLoadingSize { small, medium, large, extraLarge }

HuxLoadingSize _toHux(SLoadingSize s) => switch (s) {
      SLoadingSize.small => HuxLoadingSize.small,
      SLoadingSize.medium => HuxLoadingSize.medium,
      SLoadingSize.large => HuxLoadingSize.large,
      SLoadingSize.extraLarge => HuxLoadingSize.extraLarge,
    };

/// Sellio loading indicator component.
class SLoading extends HuxLoading {
  SLoading({
    super.key,
    SLoadingSize size = SLoadingSize.medium,
  }) : super(size: _toHux(size));
}
