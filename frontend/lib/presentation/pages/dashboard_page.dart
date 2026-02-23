library;

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../widgets/navigation/app_sidebar.dart';
import '../widgets/navigation/app_bottom_nav.dart';
import 'analytics/analytics_page.dart';
import 'prs/open_prs_page.dart';
import 'leaderboard/leaderboard_page.dart';
import 'chart/charts_page.dart';
import 'about/about_page.dart';
import 'setting/settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    AnalyticsPage(),
    OpenPrsPage(),
    LeaderboardPage(),
    ChartsPage(),
    AboutPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= LayoutConstants.mobileBreakpoint;

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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _pages[_selectedIndex],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _pages[_selectedIndex],
    );
  }
}
