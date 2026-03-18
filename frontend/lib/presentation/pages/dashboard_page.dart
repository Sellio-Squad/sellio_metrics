import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../navigation/app_bottom_nav.dart';
import '../navigation/app_sidebar.dart';

class DashboardPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardPage({super.key, required this.navigationShell});

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= LayoutConstants.mobileBreakpoint;
    final selectedIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: isDesktop
          ? _buildDesktopLayout(context, selectedIndex)
          : _buildMobileLayout(context, selectedIndex),
      bottomNavigationBar: isDesktop
          ? null
          : AppBottomNav(currentIndex: selectedIndex, onTap: _onItemTapped),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, int selectedIndex) {
    return Row(
      children: [
        AppSidebar(selectedIndex: selectedIndex, onItemSelected: _onItemTapped),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(selectedIndex),
                    child: navigationShell,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, int selectedIndex) {
    return Column(
      children: [
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: navigationShell,
          ),
        ),
      ],
    );
  }
}
