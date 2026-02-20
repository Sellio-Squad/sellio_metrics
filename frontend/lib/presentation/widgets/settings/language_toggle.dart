/// Sellio Metrics — Language Toggle Widget
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';

/// Language toggle row.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        final isArabic = settings.locale.languageCode == 'ar';
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? l10n.languageArabic : l10n.languageEnglish,
              style: AppTypography.body.copyWith(color: scheme.body),
            ),
            SSwitch(
              value: isArabic,
              onChanged: (_) => settings.toggleLocale(),
            ),
          ],
        );
      },
    );
  }
}
