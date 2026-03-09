library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'design_system/design_system.dart' show SellioThemes;
import 'l10n/app_localizations.dart';
import 'core/di/service_locator.dart';
import 'presentation/providers/app_settings_provider.dart';
import 'presentation/providers/filter_provider.dart';
import 'presentation/providers/leaderboard_provider.dart';
import 'presentation/providers/member_provider.dart';
import 'core/navigation/app_navigation.dart';

class SellioMetricsApp extends StatelessWidget {
  const SellioMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl.get<AppSettingsProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<FilterProvider>()),
      ],
      child: const _AppInitializationWrapper(),
    );
  }
}

class _AppInitializationWrapper extends StatefulWidget {
  const _AppInitializationWrapper();

  @override
  State<_AppInitializationWrapper> createState() =>
      _AppInitializationWrapperState();
}

class _AppInitializationWrapperState extends State<_AppInitializationWrapper> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    final settings = context.read<AppSettingsProvider>();
    await settings.loadRepositories();

    if (!mounted) return;
    if (settings.selectedRepos.isEmpty) return;

    final repoNames = settings.selectedRepos.map((r) => r.fullName).toList();
    sl.get<LeaderboardProvider>().fetchLeaderboard(repoNames);
    sl.get<MemberProvider>().fetchStatuses(repoNames);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
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
    );
  }
}
