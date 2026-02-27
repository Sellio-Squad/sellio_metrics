library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/app_settings_provider.dart';


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
              decoration: BoxDecoration(
                color: scheme.surfaceLow,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: scheme.stroke),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: repos.length,
                separatorBuilder: (context, index) => Divider(
                  color: scheme.stroke,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final repo = repos[index];
                  final isSelected = settings.selectedRepos.any(
                    (r) => r.fullName == repo.fullName,
                  );

                  return InkWell(
                    onTap: () => settings.toggleRepoSelection(repo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          SCheckbox(
                            value: isSelected,
                            onChanged: (_) =>
                                settings.toggleRepoSelection(repo),
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
                    ),
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
