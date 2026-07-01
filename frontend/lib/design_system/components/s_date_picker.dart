/// Sellio Design System — SDatePicker
///
/// Wrapper around HuxDatePicker that isolates the presentation layer
/// from direct Hux dependency.
library;

import 'package:hux/hux.dart';

/// Sellio date picker component.
class SDatePicker extends HuxDatePicker {
  const SDatePicker({
    super.key,
    required super.placeholder,
    super.initialDate,
    required super.firstDate,
    required super.lastDate,
    required super.onDateChanged,
  });
}
