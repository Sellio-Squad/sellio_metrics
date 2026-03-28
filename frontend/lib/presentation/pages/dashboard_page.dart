import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/presentation/navigation/app_bottom_nav.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar.dart';

enum _LayoutMode { compact, medium, expanded }

_LayoutMode _getLayoutMode(double width) {
  if (width >= 1200) return _LayoutMode.expanded;
  if (width >= 600) return _LayoutMode.medium;
  return _LayoutMode.compact;
}

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
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeController.value = 1.0;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }

    // Prevent rapid tapping from breaking the animation
    if (_isTransitioning) return;
    _isTransitioning = true;


    _fadeController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = index);
      widget.navigationShell.goBranch(index, initialLocation: false);
      _fadeController.forward().then((_) {
        _isTransitioning = false;
      });
    });
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      _fadeController
        ..value = 0
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layoutMode = _getLayoutMode(width);

    // Auto-collapse sidebar for medium screens
    final effectiveCollapsed =
        layoutMode == _LayoutMode.medium ? true : _sidebarCollapsed;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: switch (layoutMode) {
        _LayoutMode.expanded || _LayoutMode.medium => _buildDesktop(
            effectiveCollapsed,
            showCollapseToggle: layoutMode == _LayoutMode.expanded,
          ),
        _LayoutMode.compact => _buildMobile(),
      },
      bottomNavigationBar: layoutMode == _LayoutMode.compact
          ? AppBottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onItemTapped,
            )
          : null,
    );
  }

  Widget _buildDesktop(
    bool isCollapsed, {
    bool showCollapseToggle = true,
  }) {
    return Row(
      children: [
        AppSidebar(
          selectedIndex: widget.navigationShell.currentIndex,
          isCollapsed: isCollapsed,
          onItemSelected: _onItemTapped,
          onToggleCollapse: showCollapseToggle
              ? () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)
              : null, // ← null disables the toggle on medium screens
        ),
        Expanded(
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