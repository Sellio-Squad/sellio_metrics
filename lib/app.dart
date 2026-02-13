/// Sellio Metrics Dashboard — Application Root
///
/// Configures HuxTheme, Provider, and global app settings.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import 'l10n/app_strings.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/pages/dashboard_page.dart';

class SellioMetricsApp extends StatelessWidget {
  const SellioMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()..loadData()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppStrings.appTitle,
            debugShowCheckedModeBanner: false,
            theme: HuxTheme.lightTheme,
            darkTheme: HuxTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const _AppEntryPoint(),
          );
        },
      ),
    );
  }
}

/// Entry point that shows loading state or dashboard.
class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        switch (provider.status) {
          case DashboardStatus.loading:
            return _buildLoadingScreen(context);
          case DashboardStatus.error:
            return _buildErrorScreen(context);
          case DashboardStatus.loaded:
            return const DashboardPage();
        }
      },
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121A) : const Color(0xFFF5F5F7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HuxLoading(size: HuxLoadingSize.extraLarge),
            const SizedBox(height: 24),
            Text(
              AppStrings.loadingData,
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121A) : const Color(0xFFF5F5F7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            HuxButton(
              onPressed: () {
                context.read<DashboardProvider>().loadData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
