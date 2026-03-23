import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/about/about_section_header.dart';

class AboutFeaturesSection extends StatelessWidget {
  const AboutFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final features = [
      _Feature(
        title: l10n.featureMarketplace,
        icon: LucideIcons.store,
        color: const Color(0xFF3B82F6),
      ),
      _Feature(
        title: l10n.featureThrifting,
        icon: LucideIcons.recycle,
        color: const Color(0xFF0D9488),
      ),
      _Feature(
        title: l10n.featureAiDesign,
        icon: LucideIcons.brain,
        color: const Color(0xFF8B5CF6),
      ),
      _Feature(
        title: l10n.featureAnalytics,
        icon: LucideIcons.barChart3,
        color: const Color(0xFFF59E0B),
      ),
      _Feature(
        title: l10n.featureMicroservices,
        icon: LucideIcons.boxes,
        color: const Color(0xFFEF4444),
      ),
      _Feature(
        title: l10n.featureCrossplatform,
        icon: LucideIcons.monitor,
        color: const Color(0xFF06B6D4),
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionHeader(
            title: l10n.aboutKeyFeatures,
            icon: Icons.star_outline,
            subtitle: 'Everything you need to power modern e-commerce.',
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 700
                  ? 3
                  : constraints.maxWidth > 420
                  ? 2
                  : 1;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 100,
                ),
                itemCount: features.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _FeatureCard(feature: features[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: _isHovered ? scheme.primaryVariant : scheme.surfaceLow,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: _isHovered
                ? scheme.primary.withValues(alpha: 0.2)
                : scheme.stroke,
          ),
          boxShadow: _isHovered
              ? [
            BoxShadow(
              color: scheme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.feature.color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Center(
                child: Icon(
                  widget.feature.icon,
                  color: widget.feature.color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.feature.title,
                    style: AppTypography.subtitle.copyWith(
                      color: scheme.title,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.check, color: scheme.green, size: 14),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Included',
                        style: AppTypography.caption.copyWith(
                          color: scheme.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature {
  final String title;
  final IconData icon;
  final Color color;
  const _Feature({
    required this.title,
    required this.icon,
    required this.color,
  });
}