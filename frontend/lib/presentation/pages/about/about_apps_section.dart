import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/about/about_section_header.dart';

class AboutAppsSection extends StatelessWidget {
  const AboutAppsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final apps = [
      _AppInfo(
        name: l10n.aboutAppCustomerName,
        description: l10n.aboutAppCustomerDesc,
        icon: LucideIcons.shoppingBag,
        status: l10n.aboutStatusInProgress,
        statusType: _StatusType.inProgress,
        liveUrl: null,
      ),
      _AppInfo(
        name: l10n.aboutAppAdminName,
        description: l10n.aboutAppAdminDesc,
        icon: LucideIcons.shield,
        status: l10n.aboutStatusPlanned,
        statusType: _StatusType.planned,
        liveUrl: null,
      ),
      _AppInfo(
        name: l10n.aboutAppSellerName,
        description: l10n.aboutAppSellerDesc,
        icon: LucideIcons.store,
        status: l10n.aboutStatusPlanned,
        statusType: _StatusType.planned,
        liveUrl: null,
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionHeader(
            title: l10n.aboutApps,
            icon: Icons.apps,
            subtitle: 'Our ecosystem of interconnected applications.',
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 750 ? 3 : 1;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  mainAxisExtent: 220,
                ),
                itemCount: apps.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) => _AppCard(app: apps[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatefulWidget {
  final _AppInfo app;
  const _AppCard({required this.app});

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final statusColor = switch (widget.app.statusType) {
      _StatusType.live => scheme.green,
      _StatusType.inProgress => const Color(0xFFF59E0B),
      _StatusType.planned => SellioColors.blue,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: scheme.surfaceLow,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: _isHovered
                ? scheme.primary.withValues(alpha: 0.25)
                : scheme.stroke,
          ),
          boxShadow: _isHovered
              ? [
            BoxShadow(
              color: scheme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ]
              : [
            BoxShadow(
              color: scheme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Top Row: Icon + Status ──────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryVariant,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Center(
                    child: Icon(
                      widget.app.icon,
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.app.status,
                        style: AppTypography.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ─── Title ──────────────────────────────────
            Text(
              widget.app.name,
              style: AppTypography.subtitle.copyWith(
                color: scheme.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // ─── Description ────────────────────────────
            Text(
              widget.app.description,
              style: AppTypography.caption.copyWith(
                color: scheme.hint,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── CTA Button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: SButton(
                variant: widget.app.liveUrl != null
                    ? SButtonVariant.primary
                    : SButtonVariant.ghost,
                size: SButtonSize.small,
                onPressed: widget.app.liveUrl != null
                    ? () {
                  final uri = Uri.tryParse(widget.app.liveUrl!);
                  if (uri != null) {
                    launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                }
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.app.liveUrl != null
                          ? Icons.play_arrow_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      widget.app.liveUrl != null
                          ? l10n.aboutTryLive
                          : l10n.aboutComingSoon,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StatusType { live, inProgress, planned }

class _AppInfo {
  final String name;
  final String description;
  final IconData icon;
  final String status;
  final _StatusType statusType;
  final String? liveUrl;

  const _AppInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
    required this.statusType,
    this.liveUrl,
  });
}