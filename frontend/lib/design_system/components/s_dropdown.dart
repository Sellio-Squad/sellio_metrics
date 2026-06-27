import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import 's_button.dart';

class SDropdownItem<T> {
  final T value;
  final Widget child;

  const SDropdownItem({
    required this.value,
    required this.child,
  });
}

class SDropdown<T> extends StatelessWidget {
  final List<SDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String placeholder;
  final SButtonVariant variant;
  final SButtonSize size;

  const SDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.placeholder = 'Select option',
    this.variant = SButtonVariant.outline,
    this.size = SButtonSize.medium,
  });

  HuxButtonVariant _toHuxVariant(SButtonVariant v) => switch (v) {
        SButtonVariant.primary => HuxButtonVariant.primary,
        SButtonVariant.ghost => HuxButtonVariant.ghost,
        SButtonVariant.outline => HuxButtonVariant.outline,
      };

  HuxButtonSize _toHuxSize(SButtonSize s) => switch (s) {
        SButtonSize.small => HuxButtonSize.small,
        SButtonSize.medium => HuxButtonSize.medium,
        SButtonSize.large => HuxButtonSize.large,
      };

  @override
  Widget build(BuildContext context) {
    return HuxDropdown<T>(
      items: items
          .map((item) => HuxDropdownItem<T>(
                value: item.value,
                child: item.child,
              ))
          .toList(),
      value: value,
      onChanged: onChanged,
      placeholder: placeholder,
      variant: _toHuxVariant(variant),
      size: _toHuxSize(size),
    );
  }
}
