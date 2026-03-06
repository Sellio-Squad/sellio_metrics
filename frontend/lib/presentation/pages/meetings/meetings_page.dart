import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/meeting_entity.dart';
import '../../providers/meetings_provider.dart';
import '../../widgets/common/loading_screen.dart';
import 'create_meeting_dialog.dart';
import 'meeting_detail_view.dart';
import 'attendance_analytics_view.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MeetingsProvider>();
      // Only load if empty to prevent unnecessary requests on tab switch
      if (provider.meetings.isEmpty) {
        provider.loadMeetings();
        provider.loadAnalytics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.meetings.isEmpty) {
          return const LoadingScreen();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: AppSpacing.xl),

                  // Optional: rate limit banner warning if low
                  if (provider.rateLimit.isLow)
                    _buildRateLimitBanner(context, provider),

                  // Analytics section
                  if (provider.analytics.totalMeetings > 0) ...[
                    const AttendanceAnalyticsView(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // Active meetings list
                  _buildMeetingsList(context, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MeetingsProvider provider) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.meetingsTitle,
          style: AppTypography.title.copyWith(
            color: context.colors.title,
            fontSize: 28,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.isAuthenticated) ...[
              SButton(
                variant: SButtonVariant.ghost,
                onPressed: () => provider.logout(),
                child: const Text('Sign Out'),
              ),
              const SizedBox(width: AppSpacing.md),
              SButton(
                onPressed: () => _showCreateMeetingDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.plus, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.newMeeting),
                  ],
                ),
              ),
            ] else ...[
              SButton(
                variant: SButtonVariant.primary,
                onPressed: provider.isLoading
                    ? null
                    : () => _handleLogin(provider),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (provider.isLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ] else ...[
                      const Icon(LucideIcons.chrome, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    const Text('Sign In with Google'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _handleLogin(MeetingsProvider provider) async {
    await provider.login();
    if (provider.authUrl != null && provider.authUrl!.isNotEmpty) {
      final uri = Uri.parse(provider.authUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open sign in page')),
          );
        }
      }
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  Widget _buildRateLimitBanner(
    BuildContext context,
    MeetingsProvider provider,
  ) {
    final l10n = AppLocalizations.of(context);
    final limit = provider.rateLimit;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellioColors.red.withValues(alpha: 0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: SellioColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle, color: SellioColors.red),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${l10n.rateLimit}: ${limit.remaining}/${limit.limit} (${l10n.resetsIn} ${limit.resetAt})',
              style: AppTypography.body.copyWith(
                color: SellioColors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList(BuildContext context, MeetingsProvider provider) {
    final l10n = AppLocalizations.of(context);

    if (provider.meetings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.video,
                size: 64,
                color: context.colors.hint.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.noActiveMeetings,
                style: AppTypography.body.copyWith(
                  color: context.colors.hint,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.activeMeetings,
          style: AppTypography.title.copyWith(
            color: context.colors.title,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisExtent: 180,
            crossAxisSpacing: AppSpacing.xl,
            mainAxisSpacing: AppSpacing.xl,
          ),
          itemCount: provider.meetings.length,
          itemBuilder: (context, index) {
            final meeting = provider.meetings[index];
            return _MeetingCard(meeting: meeting);
          },
        ),
      ],
    );
  }

  void _showCreateMeetingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateMeetingDialog(),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingEntity meeting;

  const _MeetingCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final formatter = DateFormat('MMM d, h:mm a');

    // Simple heuristic: if created in the last 2 hours, consider it "live" roughly
    final isRecent = DateTime.now().difference(meeting.createdAt).inHours < 2;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MeetingDetailView(meetingId: meeting.id),
        );
      },
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: AppTypography.title.copyWith(
                      color: scheme.title,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRecent)
                  SBadge(label: l10n.live, variant: SBadgeVariant.success),
              ],
            ),

            Text(
              formatter.format(meeting.createdAt),
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),

            Row(
              children: [
                Icon(LucideIcons.users, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${meeting.participantCount} ${l10n.participantsCount}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: SButton(
                    variant: SButtonVariant.primary,
                    onPressed: () async {
                      final url = Uri.parse(meeting.meetingUri);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.video, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Text(l10n.joinMeeting),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
