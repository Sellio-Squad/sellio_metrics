library;

import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../about/about_meetings_section.dart';

class MeetingsPage extends StatelessWidget {
  const MeetingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: const AboutMeetingsSection(),
      ),
    );
  }
}
