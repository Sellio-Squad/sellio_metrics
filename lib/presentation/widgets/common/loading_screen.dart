library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.isDark
          ? SellioColors.darkBackground
          : SellioColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HuxLoading(size: HuxLoadingSize.extraLarge),
            SizedBox(height: AppSpacing.xl),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                l10n.loadingData,
                style: AppTypography.body.copyWith(
                  color: context.isDark
                      ? Colors.white54
                      : SellioColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
