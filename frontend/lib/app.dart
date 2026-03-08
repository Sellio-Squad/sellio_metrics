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
import 'presentation/providers/meetings_provider.dart';
import 'presentation/providers/meet_events_provider.dart';
import 'presentation/providers/pr_data_provider.dart';
import 'presentation/providers/analytics_provider.dart';
import 'presentation/pages/dashboard_page.dart';

class SellioMetricsApp extends StatelessWidget {
  const SellioMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl.get<AppSettingsProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<FilterProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<LeaderboardProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<MemberProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<MeetingsProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<MeetEventsProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<PrDataProvider>()),
        ChangeNotifierProvider(create: (_) => sl.get<AnalyticsProvider>()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    final settings = context.read<AppSettingsProvider>();
    await settings.loadRepositories();

    if (!mounted) return;
    if (settings.selectedRepos.isEmpty) return;

    // Kick off initial data loads — LeaderboardPage and MembersPage
    // also trigger their own fetches, but pre-loading here avoids a flash.
    final repoNames = settings.selectedRepos.map((r) => r.fullName).toList();
    context.read<LeaderboardProvider>().fetchLeaderboard(repoNames);
    context.read<MemberProvider>().fetchStatuses(repoNames);
  }

  @override
  Widget build(BuildContext context) {
    return const AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: DashboardPage(),
    );
  }
}
