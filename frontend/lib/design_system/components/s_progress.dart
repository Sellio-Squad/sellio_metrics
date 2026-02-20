/// Sellio Design System — SProgress
///
/// Wrapper around HuxProgress that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Progress size mirroring HuxProgressSize.
enum SProgressSize { small, medium, large }

HuxProgressSize _toHux(SProgressSize s) => switch (s) {
      SProgressSize.small => HuxProgressSize.small,
      SProgressSize.medium => HuxProgressSize.medium,
      SProgressSize.large => HuxProgressSize.large,
    };

/// Sellio progress bar component.
class SProgress extends HuxProgress {
  SProgress({
    super.key,
    required super.value,
    SProgressSize size = SProgressSize.medium,
  }) : super(size: _toHux(size));
}
