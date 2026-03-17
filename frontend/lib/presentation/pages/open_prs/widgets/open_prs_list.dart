library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../domain/entities/pr_entity.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'empty_state.dart';
import 'pr_list_tile.dart';

class OpenPrsList extends StatelessWidget {
  final List<PrEntity> prs;

  const OpenPrsList({super.key, required this.prs});

  @override
  Widget build(BuildContext context) {
    if (prs.isEmpty) {
      final scheme = context.colors;
      final l10n = AppLocalizations.of(context);
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(scheme: scheme, l10n: l10n),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => PrListTile(pr: prs[index]),
        childCount: prs.length,
      ),
    );
  }
}
