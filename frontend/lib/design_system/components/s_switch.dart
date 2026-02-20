/// Sellio Design System — SSwitch
///
/// Wrapper around HuxSwitch that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Sellio switch (toggle) component.
class SSwitch extends HuxSwitch {
  const SSwitch({
    super.key,
    required super.value,
    required super.onChanged,
  });
}
