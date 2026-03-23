import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/about/about_animated_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_apps_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_features_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_footer_cta.dart';
import 'package:sellio_metrics/presentation/pages/about/about_hero.dart';
import 'package:sellio_metrics/presentation/pages/about/about_how_to_join_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_tech_stack_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_vision_section.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            // CRITICAL: force the column to take full height minimum
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Hero ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AboutAnimatedSection(
                    delay: const Duration(milliseconds: 100),
                    child: const AboutHero(),
                  ),
                ),

                _buildDivider(scheme),

                // ─── Sections ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AboutAnimatedSection(
                        delay: const Duration(milliseconds: 200),
                        child: const AboutVisionSection(),
                      ),
                      _buildDivider(scheme),

                      AboutAnimatedSection(
                        delay: const Duration(milliseconds: 350),
                        child: const AboutFeaturesSection(),
                      ),
                      _buildDivider(scheme),

                      AboutAnimatedSection(
                        delay: const Duration(milliseconds: 500),
                        child: const AboutAppsSection(),
                      ),
                      _buildDivider(scheme),

                      AboutAnimatedSection(
                        delay: const Duration(milliseconds: 650),
                        child: const AboutTechStackSection(),
                      ),
                      _buildDivider(scheme),

                      AboutAnimatedSection(
                        delay: const Duration(milliseconds: 800),
                        child: const AboutHowToJoinSection(),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),

                // ─── Footer CTA ──────────────────────────
                AboutAnimatedSection(
                  delay: const Duration(milliseconds: 950),
                  child: const AboutFooterCta(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(SellioColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.stroke.withValues(alpha: 0),
              scheme.stroke.withValues(alpha: 0.4),
              scheme.stroke.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}