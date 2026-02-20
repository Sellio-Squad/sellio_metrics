/// Sellio Metrics — Repository Selector Widget
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/dashboard_provider.dart';

/// Repository selector dropdown.
class RepositorySelector extends StatelessWidget {
  const RepositorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

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
                l10n.settingsLoadingRepos,
                style: AppTypography.body.copyWith(color: scheme.body),
              ),
            ],
          );
        }

        final repos = settings.availableRepos;
        if (repos.isEmpty) {
          return Text(
            l10n.settingsNoRepos,
            style: AppTypography.body.copyWith(color: scheme.body),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsSelectRepo,
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
                '${l10n.settingsCurrent}: ${settings.selectedRepoFullName}',
                style: AppTypography.caption.copyWith(color: scheme.primary),
              ),
            ],
          ],
        );
      },
    );
  }
}
