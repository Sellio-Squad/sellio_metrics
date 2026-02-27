library;

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/navigation/app_navigation.dart';
import '../../design_system/design_system.dart';
import '../navigation/app_bottom_nav.dart';
import '../navigation/app_sidebar.dart';
import 'analytics/date_filter/date_range_filter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= LayoutConstants.mobileBreakpoint;

    if (_selectedIndex >= AppNavigation.routes.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: isDesktop
          ? null
          : AppBottomNav(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
            ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        AppSidebar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) => setState(() => _selectedIndex = index),
        ),
        Expanded(
          child: Column(
            children: [
              // Global date range filter, shared by all pages
              const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: DateRangeFilter(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: AppNavigation.routes[_selectedIndex].page,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: DateRangeFilter(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: AppNavigation.routes[_selectedIndex].page,
          ),
        ),
      ],
    );
  }
}
