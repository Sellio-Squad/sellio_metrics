/// Sellio Design System — SSidebar
///
/// Wrapper around HuxSidebar / HuxSidebarItemData that isolates
/// the presentation layer from direct Hux dependency.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

/// Sidebar item data mirroring HuxSidebarItemData.
class SSidebarItemData {
  final String id;
  final IconData icon;
  final String label;

  const SSidebarItemData({
    required this.id,
    required this.icon,
    required this.label,
  });

  HuxSidebarItemData toHux() => HuxSidebarItemData(
        id: id,
        icon: icon,
        label: label,
      );
}

/// Sellio sidebar component.
class SSidebar extends StatelessWidget {
  final List<SSidebarItemData> items;
  final String selectedItemId;
  final ValueChanged<String> onItemSelected;
  final Widget? header;
  final Widget? footer;

  const SSidebar({
    super.key,
    required this.items,
    required this.selectedItemId,
    required this.onItemSelected,
    this.header,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return HuxSidebar(
      items: items.map((i) => i.toHux()).toList(),
      selectedItemId: selectedItemId,
      onItemSelected: onItemSelected,
      header: header,
      footer: footer,
    );
  }
}
