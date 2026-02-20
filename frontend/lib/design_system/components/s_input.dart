/// Sellio Design System — SInput
///
/// Wrapper around HuxInput that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Sellio text input component.
class SInput extends HuxInput {
  const SInput({
    super.key,
    super.hint,
    super.onChanged,
    super.prefixIcon,
  });
}
