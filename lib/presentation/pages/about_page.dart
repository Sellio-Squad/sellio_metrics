/// Sellio Metrics — About Sellio Page
///
/// Business context page showing Sellio's mission, apps, vision,
/// how to join, and tech stack.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:url_launcher/url_launcher.dart';

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

          // Our Vision — expanded business description
          _buildSection(
            context,
            title: l10n.aboutVision,
            icon: Icons.visibility_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sellio is a startup e-commerce platform that reimagines '
                  'how people buy and sell online. We connect sellers and buyers '
                  'in a seamless marketplace for both pre-owned and new goods, '
                  'combining traditional e-commerce with modern thrifting culture.',
                  style: AppTypography.body.copyWith(
                    height: 1.8,
                    color: context.isDark
                        ? Colors.white70
                        : SellioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Our mission is to make online selling as easy as posting on '
                  'social media while providing buyers with a curated, trustworthy '
                  'shopping experience. We target the growing second-hand market '
                  'in the MENA region, where sustainability meets affordability.',
                  style: AppTypography.body.copyWith(
                    height: 1.8,
                    color: context.isDark
                        ? Colors.white70
                        : SellioColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Competitive advantages
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    _advantageChip(context, '🎯', 'MENA-first approach'),
                    _advantageChip(context, '♻️', 'Sustainability-driven'),
                    _advantageChip(context, '🤖', 'AI-powered curation'),
                    _advantageChip(context, '📱', 'Mobile-first design'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Executive Summary
          _buildSection(
            context,
            title: l10n.aboutExecutiveSummary,
            icon: Icons.summarize_outlined,
            child: Text(
              'Sellio differentiates itself through AI-powered product recommendations, '
              'integrated design generation tools, and a streamlined seller onboarding '
              'process that reduces listing time by 70%. Our scalable microservices '
              'architecture supports rapid growth, and our cross-platform Flutter apps '
              'ensure a consistent experience across iOS, Android, and Web.',
              style: AppTypography.body.copyWith(
                height: 1.7,
                color: context.isDark
                    ? Colors.white70
                    : SellioColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Our Apps — with Try Live buttons
          _buildSection(
            context,
            title: l10n.aboutApps,
            icon: Icons.apps,
            child: _buildAppsGrid(context, l10n),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Tech Stack
          _buildSection(
            context,
            title: l10n.aboutTechStack,
            icon: Icons.code,
            child: _buildTechStack(context),
          ),
          const SizedBox(height: AppSpacing.xl),

          // How to Join Us
          _buildSection(
            context,
            title: l10n.aboutHowToJoin,
            icon: Icons.group_add_outlined,
            child: _buildHowToJoin(context),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Key Features
          _buildSection(
            context,
            title: 'Key Features',
            icon: Icons.star_outline,
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
            'E-Commerce • Thrifting • AI-Powered',
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
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: SellioColors.primaryIndigo,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.title.copyWith(
                color: context.isDark ? Colors.white : SellioColors.gray700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }

  Widget _advantageChip(BuildContext context, String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: AppTypography.body.copyWith(
              color: context.isDark ? Colors.white : SellioColors.gray700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsGrid(BuildContext context, AppLocalizations l10n) {
    final apps = [
      _AppInfo(
        name: 'Customer App',
        description: 'Browse, buy, and explore curated products. '
            'Smart search, wishlists, and secure checkout.',
        icon: LucideIcons.shoppingBag,
        status: 'In Progress',
        statusColor: SellioColors.warning,
        liveUrl: null,
      ),
      _AppInfo(
        name: 'Admin Panel',
        description: 'Manage platform, users, analytics, and orders. '
            'Real-time monitoring dashboard.',
        icon: LucideIcons.shield,
        status: 'Planned',
        statusColor: SellioColors.info,
        liveUrl: null,
      ),
      _AppInfo(
        name: 'Seller App',
        description: 'List products with AI descriptions, manage orders, '
            'track sales performance.',
        icon: LucideIcons.store,
        status: 'Planned',
        statusColor: SellioColors.info,
        liveUrl: null,
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
          childAspectRatio: 1.3,
          children: apps
              .map((app) => _buildAppCard(context, app, l10n))
              .toList(),
        );
      },
    );
  }

  Widget _buildAppCard(
    BuildContext context,
    _AppInfo app,
    AppLocalizations l10n,
  ) {
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
          const SizedBox(height: AppSpacing.md),
          // Try Live button
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
                    app.liveUrl != null
                        ? l10n.aboutTryLive
                        : 'Coming Soon',
                  ),
                ],
              ),
            ),
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

  Widget _buildHowToJoin(BuildContext context) {
    final steps = [
      _JoinStep(
        icon: Icons.mail_outlined,
        title: 'Get in Touch',
        description: 'Reach out to us via email or LinkedIn to express '
            'your interest in joining the Sellio team.',
      ),
      _JoinStep(
        icon: Icons.assignment_outlined,
        title: 'Share Your Work',
        description: 'Send us your portfolio, GitHub profile, or any '
            'projects that showcase your skills.',
      ),
      _JoinStep(
        icon: Icons.rocket_launch_outlined,
        title: 'Start Contributing',
        description: 'After a quick onboarding, dive straight into real '
            'features with our agile squad.',
      ),
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: SellioColors.primaryGradient,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            step.icon,
                            size: 18,
                            color: SellioColors.primaryIndigo,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            step.title,
                            style: AppTypography.subtitle.copyWith(
                              color: context.isDark
                                  ? Colors.white
                                  : SellioColors.gray700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        step.description,
                        style: AppTypography.body.copyWith(
                          color: context.isDark
                              ? Colors.white54
                              : SellioColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  final String? liveUrl;

  const _AppInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.status,
    required this.statusColor,
    this.liveUrl,
  });
}

class _TechItem {
  final String name;
  final String role;
  final IconData icon;

  const _TechItem(this.name, this.role, this.icon);
}

class _JoinStep {
  final IconData icon;
  final String title;
  final String description;

  const _JoinStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}
