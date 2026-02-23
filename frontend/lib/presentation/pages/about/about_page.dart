library;

import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import 'about_apps_section.dart';
import 'about_features_section.dart';
import 'about_hero.dart';
import 'about_how_to_join_section.dart';
import 'about_meetings_section.dart';
import 'about_tech_stack_section.dart';
import 'about_vision_section.dart';

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
          const AboutMeetingsSection(),
          const SizedBox(height: AppSpacing.xl),
          const AboutFeaturesSection(),
        ],
      ),
    );
  }
}
