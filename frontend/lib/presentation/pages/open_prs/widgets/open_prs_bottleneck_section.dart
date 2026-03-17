library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../design_system/design_system.dart';
import '../../../../domain/entities/bottleneck_entity.dart';
import '../../../widgets/section_header.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'bottleneck_item.dart';

class OpenPrsBottleneckSection extends StatelessWidget {
  final List<BottleneckEntity> bottlenecks;

  const OpenPrsBottleneckSection({super.key, required this.bottlenecks});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        SectionHeader(
          icon: LucideIcons.alertTriangle,
          title: l10n.sectionBottlenecks,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (bottlenecks.isEmpty)
          Text(
            l10n.emptyData,
            style: AppTypography.body.copyWith(color: scheme.hint),
          )
        else
          ...bottlenecks.map((b) => BottleneckItem(bottleneck: b)),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
