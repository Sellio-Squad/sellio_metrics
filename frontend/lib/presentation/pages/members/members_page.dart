import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/components/s_avatar.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/dashboard_provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();
      dashboard.ensureDataLoaded(settings.selectedRepos);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final members = provider.memberStatuses;
        
        if (provider.status == DashboardStatus.loading && members.isEmpty) {
          return const LoadingScreen();
        }
        if (provider.status == DashboardStatus.error && members.isEmpty) {
          return ErrorScreen(
            onRetry: () {
              final settings = context.read<AppSettingsProvider>();
              provider.loadData(repos: settings.selectedRepos);
            },
          );
        }

        if (members.isEmpty) {
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
                  ...members.map((m) => _MemberRow(member: m)),
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
