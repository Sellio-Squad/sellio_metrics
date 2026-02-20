/// Sellio Design System — SCard
///
/// Wrapper around HuxCard that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Sellio card component.
class SCard extends HuxCard {
  const SCard({
    super.key,
    required super.child,
  });
}
