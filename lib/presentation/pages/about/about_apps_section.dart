/// Sellio Metrics — About Apps Section
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import 'about_section_header.dart';

class AboutAppsSection extends StatelessWidget {
  const AboutAppsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    final apps = [
      _AppInfo(
        name: 'Customer App',
        description: 'Browse, buy, and explore curated products. '
            'Smart search, wishlists, and secure checkout.',
        icon: LucideIcons.shoppingBag,
        status: 'In Progress',
        liveUrl: null,
      ),
      _AppInfo(
        name: 'Admin Panel',
        description: 'Manage platform, users, analytics, and orders. '
            'Real-time monitoring dashboard.',
        icon: LucideIcons.shield,
        status: 'Planned',
        liveUrl: null,
      ),
      _AppInfo(
        name: 'Seller App',
        description: 'List products with AI descriptions, manage orders, '
            'track sales performance.',
        icon: LucideIcons.store,
        status: 'Planned',
        liveUrl: null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AboutSectionHeader(title: l10n.aboutApps, icon: Icons.apps),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              children: apps.map((app) => _AppCard(app: app)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _AppCard extends StatelessWidget {
  final _AppInfo app;

  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(app.icon, color: scheme.primary, size: 24),
              const Spacer(),
              HuxBadge(
                label: app.status,
                variant: HuxBadgeVariant.secondary,
              ),
            ],
          ),
          const Spacer(),
          Text(
            app.name,
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            app.description,
            style: AppTypography.caption.copyWith(color: scheme.hint),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: HuxButton(
              variant: app.liveUrl != null
                  ? HuxButtonVariant.primary
                  : HuxButtonVariant.ghost,
              size: HuxButtonSize.small,
              onPressed: app.liveUrl != null
                  ? () {
                      final uri = Uri.tryParse(app.liveUrl!);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    app.liveUrl != null ? Icons.play_arrow : Icons.schedule,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    app.liveUrl != null ? l10n.aboutTryLive : 'Coming Soon',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppInfo {
  final String name;
  final String description;
  final IconData icon;
  final String status;
  final String? liveUrl;

  const _AppInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
    this.liveUrl,
  });
}
