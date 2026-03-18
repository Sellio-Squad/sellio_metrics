library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/setting/providers/app_settings_provider.dart';
import '../../../widgets/common/loading_row.dart';

class RepositorySelector extends StatelessWidget {
  const RepositorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        if (settings.isLoadingRepos) {
          return LoadingRow(label: l10n.settingsLoadingRepos);
        }

        if (settings.errorRepoLoad != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to load repositories',
                style: AppTypography.body.copyWith(color: scheme.red),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                settings.errorRepoLoad!,
                style: AppTypography.caption.copyWith(color: scheme.hint),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              SButton(
                onPressed: () => settings.loadRepositories(),
                variant: SButtonVariant.outline,
                size: SButtonSize.small,
                child: const Text('Retry'),
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
              decoration: BoxDecoration(
                color: scheme.surfaceLow,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: scheme.stroke),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: repos.length,
                separatorBuilder: (context, index) =>
                    Divider(color: scheme.stroke, height: 1),
                itemBuilder: (context, index) {
                  final repo = repos[index];
                  final isSelected = settings.selectedRepos.any(
                    (r) => r.fullName == repo.fullName,
                  );

                  return _RepoItem(
                    repo: repo,
                    isSelected: isSelected,
                    onToggle: () => settings.toggleRepoSelection(repo),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}


class _RepoItem extends StatelessWidget {
  final dynamic repo;
  final bool isSelected;
  final VoidCallback onToggle;

  const _RepoItem({
    required this.repo,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            SCheckbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repo.name,
                    style: AppTypography.body.copyWith(
                      color: scheme.title,
                    ),
                  ),
                  if (repo.description != null && repo.description!.isNotEmpty)
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
      ),
    );
  }
}
