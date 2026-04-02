
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/providers/leaderboard_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/widgets/common/error_screen.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/leaderboard_section.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/leaderboard_filter_bar.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<LeaderboardProvider>();
      provider.fetchLeaderboard();
      provider.loadAvailableRepos();
    });
  }

  void _reload() {
    context.read<LeaderboardProvider>().fetchLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Consumer<LeaderboardProvider>(
      builder: (context, provider, _) {
        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Page header ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Leaderboard',
                        style: AppTypography.heading.copyWith(color: scheme.title),
                      ),
                    ),
                    // Refresh button
                    if (!provider.isLoading)
                      IconButton(
                        icon: Icon(LucideIcons.refreshCw, size: 18, color: scheme.hint),
                        onPressed: _reload,
                        tooltip: 'Refresh',
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Filter bar ──
                const LeaderboardFilterBar(),
                const SizedBox(height: AppSpacing.lg),

                // ── Content ──
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxl),
                    child: LoadingScreen(),
                  )
                else if (provider.error != null && provider.leaderboard.isEmpty)
                  ErrorScreen(onRetry: _reload)
                else
                  LeaderboardSection(entries: provider.leaderboard),
              ],
            ),
          ),
        );
      },
    );
  }
}
