/// Sellio Metrics — About Sellio Page
///
/// Business context page showing Sellio's mission, apps, and tech stack.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Header
          _buildHero(context, l10n),
          const SizedBox(height: AppSpacing.xxl),

          // Executive Summary
          _buildSection(
            context,
            title: l10n.aboutExecutiveSummary,
            child: Text(
              'Sellio is a startup e-commerce platform. '
              'It connects sellers and buyers in a seamless marketplace for '
              'pre-owned and new goods, combining traditional e-commerce with '
              'modern thrifting culture. Sellio aims to make online selling as '
              'easy as social media posting while providing buyers with a '
              'curated, trustworthy shopping experience.',
              style: AppTypography.body.copyWith(
                height: 1.7,
                color: context.isDark
                    ? Colors.white70
                    : SellioColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Apps
          _buildSection(
            context,
            title: l10n.aboutApps,
            child: _buildAppsGrid(context),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Tech Stack
          _buildSection(
            context,
            title: l10n.aboutTechStack,
            child: _buildTechStack(context),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Key Features
          _buildSection(
            context,
            title: 'Key Features',
            child: _buildFeatures(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: SellioColors.primaryGradient,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.aboutSellio,
            style: AppTypography.heading.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'E-Commerce • Thrifting',
            style: AppTypography.body.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.title.copyWith(
            color: context.isDark ? Colors.white : SellioColors.gray700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }

  Widget _buildAppsGrid(BuildContext context) {
    final apps = [
      _AppInfo(
        name: 'Customer App',
        description: 'Browse, buy, and explore curated products.',
        icon: LucideIcons.shoppingBag,
        status: 'In Progress',
        statusColor: SellioColors.warning,
      ),
      _AppInfo(
        name: 'Admin Panel',
        description: 'Manage platform, users, and analytics.',
        icon: LucideIcons.shield,
        status: 'Planned',
        statusColor: SellioColors.info,
      ),
      _AppInfo(
        name: 'Seller App',
        description: 'List products, manage orders, and grow.',
        icon: LucideIcons.store,
        status: 'Planned',
        statusColor: SellioColors.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: apps
              .map((app) => _buildAppCard(context, app))
              .toList(),
        );
      },
    );
  }

  Widget _buildAppCard(BuildContext context, _AppInfo app) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark
            ? SellioColors.darkSurface
            : SellioColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(app.icon, color: SellioColors.primaryIndigo, size: 24),
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
              color: context.isDark ? Colors.white : SellioColors.gray700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            app.description,
            style: AppTypography.caption.copyWith(
              color: SellioColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTechStack(BuildContext context) {
    final techItems = [
      _TechItem('Flutter', 'Mobile & Web', LucideIcons.smartphone),
      _TechItem('Kotlin', 'Backend API', LucideIcons.server),
      _TechItem('GitHub Actions', 'CI/CD Pipeline', LucideIcons.gitBranch),
      _TechItem('Firebase', 'Auth & Database', LucideIcons.database),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: techItems.map((tech) {
        return Container(
          width: 180,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.isDark
                ? SellioColors.darkSurface
                : SellioColors.lightSurface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: context.isDark ? Colors.white10 : SellioColors.gray300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                tech.icon,
                color: SellioColors.primaryIndigo,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tech.name,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.isDark
                            ? Colors.white
                            : SellioColors.gray700,
                      ),
                    ),
                    Text(
                      tech.role,
                      style: AppTypography.overline.copyWith(
                        color: SellioColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final features = [
      'Multi-vendor e-commerce marketplace',
      'Thrifting & pre-owned goods',
      'AI-powered design generation',
      'Real-time analytics dashboard',
      'Scalable microservices backend',
      'Cross-platform Flutter apps',
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: features.map((feature) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: SellioColors.primaryIndigo.withAlpha(15),
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: SellioColors.primaryIndigo.withAlpha(40),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.check,
                color: SellioColors.success,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                feature,
                style: AppTypography.body.copyWith(
                  color: context.isDark
                      ? Colors.white
                      : SellioColors.gray700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AppInfo {
  final String name;
  final String description;
  final IconData icon;
  final String status;
  final Color statusColor;

  const _AppInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
    required this.statusColor,
  });
}

class _TechItem {
  final String name;
  final String role;
  final IconData icon;

  const _TechItem(this.name, this.role, this.icon);
}
