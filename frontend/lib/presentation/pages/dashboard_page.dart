import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sellio_metrics/core/constants/layout_constants.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/presentation/navigation/app_bottom_nav.dart';
import 'package:sellio_metrics/presentation/navigation/app_sidebar.dart';

class DashboardPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardPage({super.key, required this.navigationShell});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  bool _sidebarCollapsed = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    // Start fully visible
    _fadeController.value = 1.0;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) {
      // Same tab — go to initial location
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }

    // Different tab — fade out → switch → fade in
    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = index);
      widget.navigationShell.goBranch(index, initialLocation: false);
      _fadeController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if external navigation happened (e.g., deep link)
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      _fadeController.value = 0;
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= LayoutConstants.mobileBreakpoint;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: isDesktop
          ? _buildDesktop()
          : _buildMobile(),
      bottomNavigationBar: isDesktop
          ? null
          : AppBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
        AppSidebar(
          selectedIndex: widget.navigationShell.currentIndex,
          isCollapsed: _sidebarCollapsed,
          onItemSelected: _onItemTapped,
          onToggleCollapse: () {
            setState(() => _sidebarCollapsed = !_sidebarCollapsed);
          },
        ),
        Expanded(
          // ─── Single navigationShell + FadeTransition ───
          // No AnimatedSwitcher, no KeyedSubtree, no duplicate keys
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.navigationShell,
          ),
        ),
      ],
    );
  }

  Widget _buildMobile() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.navigationShell,
    );
  }
}