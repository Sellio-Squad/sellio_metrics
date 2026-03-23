
import 'package:flutter/material.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/about/about_apps_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_features_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_hero.dart';
import 'package:sellio_metrics/presentation/pages/about/about_how_to_join_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_tech_stack_section.dart';
import 'package:sellio_metrics/presentation/pages/about/about_vision_section.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AboutHero(),
          const SizedBox(height: AppSpacing.xxl),
          const AboutVisionSection(),
          const SizedBox(height: AppSpacing.xl),
          const AboutAppsSection(),
          const SizedBox(height: AppSpacing.xl),
          const AboutTechStackSection(),
          const SizedBox(height: AppSpacing.xl),
          const AboutHowToJoinSection(),
          const SizedBox(height: AppSpacing.xl),
          const AboutFeaturesSection(),
        ],
      ),
    );
  }
}
