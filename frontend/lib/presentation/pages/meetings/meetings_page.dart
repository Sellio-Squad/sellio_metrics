// ─── Meetings Page ────────────────────────────────────────────────────────────
//
// Top-level meetings screen. Manages:
//  • Inline AnimatedSwitcher between main list and MeetingDetailView
//  • Header with SBreadcrumbs when drilling into a meeting
//  • Auth flow (sign-in / sign-out)
//  • Animated CreateMeetingPanel

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_screen.dart';
import 'package:sellio_metrics/presentation/pages/meetings/create_meeting_panel.dart';
import 'package:sellio_metrics/presentation/pages/meetings/meeting_detail_view.dart';
import 'package:sellio_metrics/presentation/pages/meetings/regular_meetings_section.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/meeting_card.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage>
    with SingleTickerProviderStateMixin {
  Timer? _authPollingTimer;
  String? _selectedMeetingId;
  bool _showCreateForm = false;

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<MeetingsProvider>();
      if (provider.meetings.isEmpty) provider.loadMeetings();
    });
  }

  @override
  void dispose() {
    _authPollingTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _openDetail(String meetingId) {
    setState(() => _selectedMeetingId = meetingId);
  }

  void _closeDetail() {
    final provider = context.read<MeetingsProvider>();
    provider.clearSelection();
    setState(() => _selectedMeetingId = null);
  }

  void _toggleCreateForm() {
    setState(() => _showCreateForm = !_showCreateForm);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading &&
            provider.meetings.isEmpty &&
            _selectedMeetingId == null) {
          return const LoadingScreen();
        }

        return Column(
          children: [
            _buildHeader(context, provider),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedMeetingId != null
                    ? MeetingDetailView(
                        key: ValueKey('detail_$_selectedMeetingId'),
                        meetingId: _selectedMeetingId!,
                        onBack: _closeDetail,
                      )
                    : _buildMainContent(context, provider),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, MeetingsProvider provider) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // ── Breadcrumb navigation
          if (_selectedMeetingId != null) ...[
            SBreadcrumbs(
              items: [
                SBreadcrumbItem(
                  label: 'Meetings',
                  onTap: _closeDetail,
                ),
                SBreadcrumbItem(
                  label: provider.selectedMeeting?.title ?? '...',
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child:
                  Icon(LucideIcons.video, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Meetings',
              style: AppTypography.subtitle.copyWith(
                color: scheme.title,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const Spacer(),

          if (provider.isAuthenticated && _selectedMeetingId == null) ...[
            SButton(
              variant: SButtonVariant.ghost,
              size: SButtonSize.small,
              onPressed: provider.logout,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.logOut, size: 14, color: scheme.hint),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Sign Out', style: TextStyle(color: scheme.hint)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SButton(
              onPressed: _toggleCreateForm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showCreateForm ? LucideIcons.x : LucideIcons.plus,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(_showCreateForm ? 'Cancel' : l10n.newMeeting),
                ],
              ),
            ),
          ] else if (!provider.isAuthenticated) ...[
            SButton(
              variant: SButtonVariant.primary,
              onPressed:
                  provider.isLoading ? null : () => _handleLogin(provider),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isLoading) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const Icon(LucideIcons.chrome, size: 16),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Sign In with Google'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Main Content ──────────────────────────────────────────────────────────

  Widget _buildMainContent(BuildContext context, MeetingsProvider provider) {
    return Align(
      key: const ValueKey('main_content'),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Subscription warning
            if (provider.meetings.any((m) => !m.subscribed))
              _SubscriptionWarningBanner(),

            // ── Inline create form
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showCreateForm
                  ? Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: CreateMeetingPanel(
                        onCreated: () =>
                            setState(() => _showCreateForm = false),
                        onCancel: () =>
                            setState(() => _showCreateForm = false),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Unauthenticated state
            if (!provider.isAuthenticated)
              _UnauthenticatedState(
                  onSignIn: () => _handleLogin(provider)),

            // ── Meetings grid
            if (provider.isAuthenticated)
              _buildMeetingsGrid(context, provider),

            const SizedBox(height: AppSpacing.xxl),

            // ── Regular meetings schedule (driven from data layer)
            if (provider.regularMeetings.isNotEmpty)
              RegularMeetingsSection(meetings: provider.regularMeetings),
          ],
        ),
      ),
    );
  }

  // ─── Meetings Grid (full-width, no overflow) ───────────────────────────────

  Widget _buildMeetingsGrid(
      BuildContext context, MeetingsProvider provider) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    if (provider.meetings.isEmpty) {
      return _EmptyMeetingsState(onCreateTap: _toggleCreateForm);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.activeMeetings,
              style: AppTypography.title.copyWith(
                color: scheme.title,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                '${provider.meetings.length}',
                style: AppTypography.caption.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Full-width responsive grid; 1 col on narrow, 2 on wide
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final meetings = provider.meetings;

            if (isWide) {
              // Two-column grid using Row+Wrap approach to avoid overflow
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 210,
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                ),
                itemCount: meetings.length,
                itemBuilder: (context, index) {
                  return MeetingCard(
                    meeting: meetings[index],
                    onTap: () => _openDetail(meetings[index].id),
                  );
                },
              );
            }

            // Single column on narrow screens
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: meetings.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                return SizedBox(
                  height: 210,
                  child: MeetingCard(
                    meeting: meetings[index],
                    onTap: () => _openDetail(meetings[index].id),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _handleLogin(MeetingsProvider provider) async {
    await provider.login();
    if (provider.authUrl != null && provider.authUrl!.isNotEmpty) {
      final uri = Uri.parse(provider.authUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _authPollingTimer?.cancel();
        _authPollingTimer =
            Timer.periodic(const Duration(seconds: 2), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }
          await provider.checkAuthStatus();
          if (provider.isAuthenticated) {
            timer.cancel();
            provider.loadMeetings();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(LucideIcons.checkCircle,
                          color: Colors.white, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      const Text('Successfully signed in with Google!'),
                    ],
                  ),
                  backgroundColor: SellioColors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll),
                ),
              );
            }
          }
        });
      }
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNAUTHENTICATED STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _UnauthenticatedState extends StatelessWidget {
  final VoidCallback onSignIn;

  const _UnauthenticatedState({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.symmetric(vertical: 48),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: scheme.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.08),
                    scheme.primary.withValues(alpha: 0.03),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.video, size: 40, color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Connect Google Meet',
              style: AppTypography.title
                  .copyWith(color: scheme.title, fontSize: 22),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sign in with your Google account to create meetings, track attendance in real time, and manage participants.',
              style: AppTypography.body
                  .copyWith(color: scheme.hint, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SButton(
              variant: SButtonVariant.primary,
              onPressed: onSignIn,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.chrome, size: 18),
                  SizedBox(width: AppSpacing.sm),
                  Text('Sign In with Google'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY MEETINGS STATE
// ═══════════════════════════════════════════════════════════════════════════════

class _EmptyMeetingsState extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyMeetingsState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.video, size: 48,
                  color: scheme.hint.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.noActiveMeetings,
              style: AppTypography.title
                  .copyWith(color: scheme.title, fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your first meeting to start tracking attendance.',
              style: AppTypography.body.copyWith(color: scheme.hint),
            ),
            const SizedBox(height: AppSpacing.xl),
            SButton(
              variant: SButtonVariant.outline,
              onPressed: onCreateTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.plus, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.newMeeting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION WARNING
// ═══════════════════════════════════════════════════════════════════════════════

class _SubscriptionWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SellioColors.red.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: SellioColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: SellioColors.red.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(LucideIcons.alertTriangle,
                color: SellioColors.red, size: 16),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking Unavailable',
                  style: AppTypography.body.copyWith(
                    color: SellioColors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Some meetings are not subscribed to real-time events. '
                  'Participant tracking will be unavailable for those meetings.',
                  style: AppTypography.caption.copyWith(
                    color: SellioColors.red.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}