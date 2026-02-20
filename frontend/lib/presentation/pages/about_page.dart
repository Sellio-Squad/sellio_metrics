/// Sellio Metrics — About Sellio Page
///
/// Orchestrator page — delegates each section to a focused sub-widget.
/// Follows SRP: this file only handles layout and section ordering.
library;

import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
import 'about/about_apps_section.dart';
import 'about/about_features_section.dart';
import 'about/about_hero.dart';
import 'about/about_how_to_join_section.dart';
import 'about/about_tech_stack_section.dart';
import 'about/about_vision_section.dart';

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
