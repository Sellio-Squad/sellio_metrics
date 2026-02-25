/// Sellio Metrics — Theme Toggle Widget
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';

/// Theme toggle row.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsTheme,
              style: AppTypography.body.copyWith(color: scheme.body),
            ),
            SSwitch(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleTheme(),
            ),
          ],
        );
      },
    );
  }
}
