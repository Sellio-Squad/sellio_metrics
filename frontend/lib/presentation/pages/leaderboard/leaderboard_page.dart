library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../design_system/design_system.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/pr_data_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../../domain/services/filter_service.dart';
import '../../../core/di/service_locator.dart';
import '../../widgets/common/loading_screen.dart';
import '../../widgets/common/error_screen.dart';
import 'leaderboard_section.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late PrDataProvider _prData;
  late FilterProvider _filter;

  @override
  void initState() {
    super.initState();
    _prData = context.read<PrDataProvider>();
    _filter = context.read<FilterProvider>();

    _prData.addListener(_onDataChanged);
    _filter.addListener(_onDataChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      if (_prData.allPrs.isEmpty) {
        _prData.ensureDataLoaded(settings.selectedRepos);
      } else {
        _onDataChanged();
      }
    });
  }

  @override
  void dispose() {
    _prData.removeListener(_onDataChanged);
    _filter.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    if (_prData.status != DataLoadingStatus.loaded) return;

    final leaderboardProvider = context.read<LeaderboardProvider>();
    final filterService = sl.get<FilterService>();

    final weekFiltered = filterService.filterByWeek(
      filterService.filterByDateRange(
        _prData.allPrs,
        _filter.startDate,
        _filter.endDate,
      ),
      _filter.weekFilter,
    );

    leaderboardProvider.fetchLeaderboard(weekFiltered);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PrDataProvider, FilterProvider, LeaderboardProvider>(
      builder: (context, prData, filter, leaderboardProvider, _) {
        if (prData.status == DataLoadingStatus.loading ||
            leaderboardProvider.isLoading) {
          return const LoadingScreen();
        }
        if (prData.status == DataLoadingStatus.error) {
          return ErrorScreen(
            onRetry: () {
              final settings = context.read<AppSettingsProvider>();
              prData.loadData(repos: settings.selectedRepos);
            },
          );
        }

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: LeaderboardSection(entries: leaderboardProvider.leaderboard),
          ),
        );
      },
    );
  }
}
