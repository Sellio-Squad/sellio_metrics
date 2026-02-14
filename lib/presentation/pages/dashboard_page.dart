/// Sellio Metrics — Dashboard Page (App Shell)
///
/// Minimal compositor: sidebar (desktop) / bottom nav (mobile) + page content.
/// Navigation logic only — no business logic here.
library;

import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/navigation/app_sidebar.dart';
import '../widgets/navigation/app_bottom_nav.dart';
import 'analytics_page.dart';
import 'open_prs_page.dart';
import 'team_page.dart';
import 'charts_page.dart';
import 'about_page.dart';
import 'settings_page.dart';

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
    TeamPage(),
    ChartsPage(),
    AboutPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

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
