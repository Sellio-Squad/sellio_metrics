library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hux/hux.dart' show HuxTheme;
import 'package:provider/provider.dart';
import 'core/l10n/app_localizations.dart';
import 'core/di/service_locator.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/app_settings_provider.dart';
import 'presentation/widgets/common/loading_screen.dart';
import 'presentation/widgets/common/error_screen.dart';
import 'presentation/pages/dashboard_page.dart';

class SellioMetricsApp extends StatelessWidget {
  const SellioMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl.get<AppSettingsProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<DashboardProvider>()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Sellio Squad Dashboard',
            debugShowCheckedModeBanner: false,
            theme: HuxTheme.lightTheme,
            darkTheme: HuxTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _AppEntryPoint(),
          );
        },
      ),
    );
  }
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Defer until after the first frame is fully built to avoid
      // "setState() called during build" when notifyListeners() fires.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeData();
      });
    }
  }

  Future<void> _initializeData() async {
    final settings = context.read<AppSettingsProvider>();
    final dashboard = context.read<DashboardProvider>();

    // Load available repos first, then load data for the selected repo
    await settings.loadRepositories();

    // If no repos were loaded (e.g. network error), trigger error state
    if (settings.selectedRepos.isEmpty) {
      dashboard.setError('No repositories available. Check your network connection.');
      return;
    }

    // Load dashboard data for the selected (or default) repos
    dashboard.loadData(repos: settings.selectedRepos);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (provider.status) {
            DashboardStatus.loading => const LoadingScreen(),
            DashboardStatus.error => ErrorScreen(
              onRetry: () => _initializeData(),
            ),
            DashboardStatus.loaded => const DashboardPage(),
          },
        );
      },
    );
  }
}
