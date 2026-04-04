import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/presentation/pages/setting/providers/app_settings_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/filter_provider.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

class SellioMetricsApp extends StatefulWidget {
  const SellioMetricsApp({super.key});

  @override
  State<SellioMetricsApp> createState() => _SellioMetricsAppState();
}

class _SellioMetricsAppState extends State<SellioMetricsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<AppSettingsProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<FilterProvider>()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp.router(
            routerConfig: AppNavigation.router,
            title: 'Sellio Squad Dashboard',
            debugShowCheckedModeBanner: false,
            theme: SellioThemes.lightTheme,
            darkTheme: SellioThemes.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
