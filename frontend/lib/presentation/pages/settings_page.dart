/// Sellio Metrics — Settings Page
///
/// Configuration panel for theme, locale, and repository selection.
/// Follows SRP — each setting section is a separate sub-widget.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/dashboard_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navSettings,
            style: AppTypography.headline.copyWith(color: scheme.title),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // Repository Selection
          _SettingsSection(
            title: 'Repository',
            icon: Icons.source_outlined,
            children: [
              const _RepositorySelector(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Appearance
          _SettingsSection(
            title: l10n.settingsTheme,
            icon: Icons.palette_outlined,
            children: [
              const _ThemeToggle(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // Language
          _SettingsSection(
            title: l10n.settingsLanguage,
            icon: Icons.translate,
            children: [
              const _LanguageToggle(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable settings section container.
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.subtitle.copyWith(color: scheme.title),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

/// Repository selector dropdown.
class _RepositorySelector extends StatelessWidget {
  const _RepositorySelector();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        if (settings.isLoadingRepos) {
          return Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Loading repositories...',
                style: AppTypography.body.copyWith(color: scheme.body),
              ),
            ],
          );
        }

        final repos = settings.availableRepos;
        if (repos.isEmpty) {
          return Text(
            'No repositories available',
            style: AppTypography.body.copyWith(color: scheme.body),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select which repository to show metrics for:',
              style: AppTypography.caption.copyWith(color: scheme.body),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceLow,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: scheme.stroke),
              ),
              child: DropdownButton<String>(
                value: repos.any((r) => r.fullName == settings.selectedRepoFullName)
                    ? settings.selectedRepoFullName
                    : repos.first.fullName,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                dropdownColor: scheme.surfaceLow,
                style: AppTypography.body.copyWith(color: scheme.title),
                icon: Icon(Icons.expand_more, color: scheme.body),
                items: repos.map((repo) {
                  return DropdownMenuItem<String>(
                    value: repo.fullName,
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                repo.name,
                                style: AppTypography.body.copyWith(
                                  color: scheme.title,
                                ),
                              ),
                              if (repo.description != null &&
                                  repo.description!.isNotEmpty)
                                Text(
                                  repo.description!,
                                  style: AppTypography.caption.copyWith(
                                    color: scheme.body,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final selected = repos.firstWhere(
                    (r) => r.fullName == value,
                  );
                  settings.setSelectedRepo(selected);

                  // Reload dashboard with new repo
                  final dashboard = context.read<DashboardProvider>();
                  dashboard.loadData(
                    owner: settings.selectedOwner,
                    repo: settings.selectedRepoName,
                  );
                },
              ),
            ),
            if (settings.selectedRepoFullName.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Current: ${settings.selectedRepoFullName}',
                style: AppTypography.caption.copyWith(color: scheme.primary),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Theme toggle row.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

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
            HuxSwitch(
              value: settings.isDarkMode,
              onChanged: (_) => settings.toggleTheme(),
            ),
          ],
        );
      },
    );
  }
}

/// Language toggle row.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

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
            HuxSwitch(
              value: isArabic,
              onChanged: (_) => settings.toggleLocale(),
            ),
          ],
        );
      },
    );
  }
}
