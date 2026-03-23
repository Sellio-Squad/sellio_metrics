import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/presentation/pages/setting/providers/app_settings_provider.dart';
import 'package:sellio_metrics/presentation/pages/members/providers/member_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/widgets/common/error_screen.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/members_header.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/members_grid.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/members_empty_state.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final AppSettingsProvider _settings;
  Set<String> _lastLoadedRepos = {};

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppSettingsProvider>();
    _settings.addListener(_onSettingsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMembers();
    });
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final currentRepos =
    _settings.selectedRepos.map((r) => r.fullName).toSet();
    if (!_setsEqual(currentRepos, _lastLoadedRepos)) {
      _loadMembers();
    }
  }

  void _loadMembers() {
    final repoNames =
    _settings.selectedRepos.map((r) => r.fullName).toList();
    _lastLoadedRepos = repoNames.toSet();
    if (repoNames.isEmpty) return;
    context.read<MemberProvider>().fetchStatuses(repoNames);
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MemberProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const LoadingScreen();
        }

        if (provider.error != null && provider.memberStatuses.isEmpty) {
          return ErrorScreen(onRetry: _loadMembers);
        }

        if (provider.memberStatuses.isEmpty) {
          return const MembersEmptyState();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MembersHeader(
                activeCount: provider.activeCount,
                inactiveCount: provider.inactiveCount,
              ),
              const SizedBox(height: AppSpacing.xl),
              MembersGrid(members: provider.memberStatuses),
            ],
          ),
        );
      },
    );
  }
}
