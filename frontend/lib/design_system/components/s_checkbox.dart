library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

/// A wrapper around HuxCheckbox to decouple the application from the Hux library.
class SCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final bool isDisabled;

  const SCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return HuxCheckbox(
      value: value,
      onChanged: onChanged,
      label: label,
      isDisabled: isDisabled,
    );
  }
}
