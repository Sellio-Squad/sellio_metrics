library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';
import 'di/service_locator.dart';
import 'l10n/app_localizations.dart';
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

class _AppEntryPoint extends StatelessWidget {
  const _AppEntryPoint();

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (provider.status) {
            DashboardStatus.loading => const LoadingScreen(),
            DashboardStatus.error => ErrorScreen(
              onRetry: () => provider.loadData(),
            ),
            DashboardStatus.loaded => const DashboardPage(),
          },
        );
      },
    );
  }
}
