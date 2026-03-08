import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/navigation/app_navigation.dart';
import '../../design_system/design_system.dart';
import '../navigation/app_bottom_nav.dart';
import '../navigation/app_sidebar.dart';
import '../widgets/date_filter/date_range_filter.dart';

class DashboardPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardPage({
    super.key,
    required this.navigationShell,
  });

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
          : AppBottomNav(
              currentIndex: selectedIndex,
              onTap: _onItemTapped,
            ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, int selectedIndex) {
    final currentRoute = AppNavigation.routes[selectedIndex];
    final showDateFilter = currentRoute.showDateFilter;

    return Row(
      children: [
        AppSidebar(
          selectedIndex: selectedIndex,
          onItemSelected: _onItemTapped,
        ),
        Expanded(
          child: Column(
            children: [
              if (showDateFilter) ...[
                const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: DateRangeFilter(),
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
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
    final currentRoute = AppNavigation.routes[selectedIndex];
    final showDateFilter = currentRoute.showDateFilter;
    return Column(
      children: [
        if (showDateFilter) ...[
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: DateRangeFilter(),
            ),
          ),
          const Divider(height: 1),
        ],
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
