/// Sellio Metrics — Dashboard Page (Shell)
///
/// Main application shell with responsive sidebar navigation and content area.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';

import '../providers/theme_provider.dart';
import 'analytics_page.dart';
import 'open_prs_page.dart';
import 'team_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  static const _pages = <Widget>[
    AnalyticsPage(),
    OpenPrsPage(),
    TeamPage(),
    SettingsPage(),
  ];

  static const _navItems = [
    _NavItem(Icons.analytics_outlined, Icons.analytics, AppStrings.navAnalytics),
    _NavItem(Icons.call_merge_outlined, Icons.call_merge, AppStrings.navOpenPrs),
    _NavItem(Icons.groups_outlined, Icons.groups, AppStrings.navTeam),
    _NavItem(Icons.settings_outlined, Icons.settings, AppStrings.navSettings),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return _buildMobileLayout(isDark);
    }
    return _buildDesktopLayout(isDark);
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121A) : const Color(0xFFF5F5F7),
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _sidebarExpanded ? 260 : 72,
            child: _buildSidebar(isDark),
          ),
          // Content
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121A) : const Color(0xFFF5F5F7),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildSidebar(bool isDark) {
    final bgColor =
        isDark ? const Color(0xFF181825) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isDark
                ? const Color(0xFF2E2E3E)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? AppSpacing.xl : AppSpacing.md,
              vertical: AppSpacing.xl,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    gradient: SellioColors.primaryGradient,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: const Icon(
                    Icons.insights,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              SellioColors.primaryGradient
                                  .createShader(bounds),
                          child: Text(
                            'Sellio',
                            style: AppTypography.title.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          'Squad Dashboard',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: _sidebarExpanded ? AppSpacing.md : AppSpacing.xs,
              ),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = _selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppRadius.mdAll,
                    child: InkWell(
                      borderRadius: AppRadius.mdAll,
                      onTap: () => setState(() => _selectedIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded
                              ? AppSpacing.lg
                              : AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SellioColors.primaryIndigo
                                  .withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: AppRadius.mdAll,
                          border: isSelected
                              ? Border.all(
                                  color: SellioColors.primaryIndigo
                                      .withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: _sidebarExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? item.activeIcon
                                  : item.icon,
                              size: 20,
                              color: isSelected
                                  ? SellioColors.primaryIndigo
                                  : isDark
                                      ? Colors.white54
                                      : const Color(0xFF6B7280),
                            ),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                item.label,
                                style: AppTypography.body.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? SellioColors.primaryIndigo
                                      : isDark
                                          ? Colors.white70
                                          : const Color(0xFF374151),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Collapse toggle
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: IconButton(
              icon: Icon(
                _sidebarExpanded
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              onPressed: () {
                setState(() => _sidebarExpanded = !_sidebarExpanded);
              },
            ),
          ),

          // Theme toggle at bottom
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? AppSpacing.xl : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                if (!_sidebarExpanded) {
                  return IconButton(
                    icon: Icon(
                      themeProvider.isDark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    onPressed: () => themeProvider.toggleTheme(),
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          themeProvider.isDark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          size: 16,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          themeProvider.isDark ? 'Dark' : 'Light',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    HuxSwitch(
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181825) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF2E2E3E)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SellioColors.primaryIndigo.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        size: 22,
                        color: isSelected
                            ? SellioColors.primaryIndigo
                            : isDark
                                ? Colors.white54
                                : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? SellioColors.primaryIndigo
                              : isDark
                                  ? Colors.white54
                                  : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
