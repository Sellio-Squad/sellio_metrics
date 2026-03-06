import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/components/s_avatar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/pr_data_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/member_provider.dart';
import '../../../domain/services/filter_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/entities/member_status_entity.dart';
import 'package:intl/intl.dart';
import '../../widgets/common/loading_screen.dart';
import '../../widgets/common/error_screen.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
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

    final memberProvider = context.read<MemberProvider>();
    final filterService = sl.get<FilterService>();

    final weekFiltered = filterService.filterByWeek(
      filterService.filterByDateRange(_prData.allPrs, _filter.startDate, _filter.endDate),
      _filter.weekFilter,
    );

    memberProvider.fetchStatuses(weekFiltered);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PrDataProvider, FilterProvider, MemberProvider>(
      builder: (context, prData, filter, memberProvider, _) {
        if (prData.status == DataLoadingStatus.loading || memberProvider.isLoading) {
          return const LoadingScreen();
        }
        if (prData.status == DataLoadingStatus.error && memberProvider.memberStatuses.isEmpty) {
          return ErrorScreen(
            onRetry: () {
              final settings = context.read<AppSettingsProvider>();
              prData.loadData(repos: settings.selectedRepos);
            },
          );
        }

        if (memberProvider.memberStatuses.isEmpty) {
          final l10n = AppLocalizations.of(context);
          return Center(
            child: Text(
              l10n.emptyData,
              style: AppTypography.body.copyWith(
                color: context.colors.hint,
                fontSize: 18,
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).navMembers,
                    style: AppTypography.title.copyWith(
                      color: context.colors.title,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ...memberProvider.memberStatuses.map((m) => _MemberRow(member: m)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  final MemberStatusEntity member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    
    // Format date if present
    String dateStr = '';
    if (member.lastActiveDate != null) {
      final formatter = DateFormat('MMM d, yyyy');
      dateStr = 'Last active: ${formatter.format(member.lastActiveDate!)}';
    } else {
      dateStr = 'No recent activity';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
        ),
        child: Opacity(
          opacity: member.isActive ? 1.0 : 0.6,
          child: Row(
            children: [
              SAvatar(
                name: member.developer,
                imageUrl: member.avatarUrl?.isNotEmpty == true ? member.avatarUrl : null,
                size: SAvatarSize.medium,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.developer,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.title,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: AppTypography.caption.copyWith(
                        color: scheme.hint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: member.isActive ? scheme.primaryVariant : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  member.isActive ? 'Active' : 'Inactive',
                  style: AppTypography.caption.copyWith(
                    color: member.isActive ? scheme.primary : scheme.hint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
