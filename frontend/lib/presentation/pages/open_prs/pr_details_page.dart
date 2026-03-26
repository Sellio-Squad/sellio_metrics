/// PR Details Page
///
/// Full-page view for a single PR, accessed via `/prs/:prNumber`.
/// Uses breadcrumbs for navigation back to the Open PRs list.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/enums/pr_size_category.dart';
import 'package:sellio_metrics/domain/services/pr_analysis_service.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/providers/pr_data_provider.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_details_header.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_code_insights_section.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_media_section.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_ticket_link_section.dart';
import 'package:sellio_metrics/presentation/pages/open_prs/widgets/pr_expanded_details.dart';
import 'package:sellio_metrics/presentation/pages/review/providers/review_provider.dart';

class PrDetailsPage extends StatelessWidget {
  final int prNumber;

  const PrDetailsPage({super.key, required this.prNumber});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Consumer<PrDataProvider>(
      builder: (context, prData, _) {
        if (prData.openPrs.isEmpty && prData.openPrsStatus != DataLoadingStatus.loading && prData.openPrsStatus != DataLoadingStatus.error) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            prData.loadOpenPrs();
          });
        }

        if (prData.openPrsStatus == DataLoadingStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final pr = _findPr(prData);

        if (pr == null) {
          return _NotFoundView(
            prNumber: prNumber,
            onBack: () => context.go('/prs'),
          );
        }

        final sizeCategory = PrAnalysisService.categorizeSize(pr);
        final sizeHints = PrAnalysisService.sizeHints(pr);

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Breadcrumbs ──────────────────────────
              Row(
                children: [
                  SBreadcrumbs(
                    items: [
                      SBreadcrumbItem(
                        label: 'Open PRs',
                        onTap: () => context.go('/prs'),
                      ),
                      SBreadcrumbItem(label: 'PR #$prNumber'),
                    ],
                  ),
                  const Spacer(),
                  _AiReviewButton(pr: pr),
                  const SizedBox(width: AppSpacing.sm),
                  _OpenOnGitHubButton(url: pr.url),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Scrollable Content ──────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrDetailsHeader(
                        pr: pr,
                        sizeCategory: sizeCategory,
                        isStarred: PrAnalysisService.isStarred(pr),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ─── Size Hints (if large) ─────────
                      if (sizeHints.isNotEmpty) ...[
                        _SizeHintsCard(
                          sizeCategory: sizeCategory,
                          hints: sizeHints,
                          scheme: scheme,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // ─── Sections Grid ─────────────────
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 800;

                          final sections = [
                            PrCodeInsightsSection(pr: pr),
                            PrMediaSection(pr: pr),
                            PrTicketLinkSection(pr: pr),
                          ];

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (int i = 0; i < sections.length; i++) ...[
                                  if (i > 0)
                                    const SizedBox(width: AppSpacing.lg),
                                  Expanded(child: sections[i]),
                                ],
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < sections.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(height: AppSpacing.lg),
                                sections[i],
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ─── Existing Details (Timeline, Participants, Metrics)
                      PrExpandedDetails(pr: pr),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PrEntity? _findPr(PrDataProvider prData) {
    try {
      return prData.openPrs.firstWhere((pr) => pr.prNumber == prNumber);
    } catch (_) {
      return null;
    }
  }
}

// ─── Private Widgets ──────────────────────────────────────────

class _OpenOnGitHubButton extends StatelessWidget {
  final String url;

  const _OpenOnGitHubButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return SButton(
      variant: SButtonVariant.ghost,
      onPressed: () {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.externalLink, size: 14),
          const SizedBox(width: 6),
          const Text('Open on GitHub'),
        ],
      ),
    );
  }
}

class _AiReviewButton extends StatelessWidget {
  final PrEntity pr;

  const _AiReviewButton({required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return SButton(
      variant: SButtonVariant.outline,
      onPressed: () {
        // Parse owner and repo from the PR URL: github.com/owner/repo/pull/N
        String owner = ApiConfig.defaultOrg;
        String repo = ApiConfig.defaultRepo;
        try {
          final uri = Uri.parse(pr.url);
          final parts = uri.pathSegments;
          if (parts.length >= 2) {
            owner = parts[0];
            repo = parts[1];
          }
        } catch (_) {}

        // Pre-fill the ReviewProvider with this PR's info
        final reviewProvider = getIt<ReviewProvider>();
        reviewProvider.prefill(owner: owner, repo: repo, prNumber: pr.prNumber);

        context.go('/review');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.sparkles, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            'AI Review',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SizeHintsCard extends StatelessWidget {
  final PrSizeCategory sizeCategory;
  final List<String> hints;
  final dynamic scheme;

  const _SizeHintsCard({
    required this.sizeCategory,
    required this.hints,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isXl = sizeCategory == PrSizeCategory.xl;
    final hintColor = isXl ? scheme.red : SellioColors.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: hintColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: hintColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isXl ? Icons.warning_amber_rounded : Icons.info_outline,
            color: hintColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PR Size: ${sizeCategory.label}',
                  style: AppTypography.body.copyWith(
                    color: hintColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...hints.map(
                  (hint) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $hint',
                      style: AppTypography.caption.copyWith(
                        color: scheme.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  final int prNumber;
  final VoidCallback onBack;

  const _NotFoundView({required this.prNumber, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SBreadcrumbs(
            items: [
              SBreadcrumbItem(label: 'Open PRs', onTap: onBack),
              SBreadcrumbItem(label: 'PR #$prNumber'),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off_outlined,
                  size: 48,
                  color: scheme.hint,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'PR #$prNumber not found',
                  style: AppTypography.title.copyWith(color: scheme.title),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This PR may have been closed, merged, or is not in the current data set.',
                  style: AppTypography.body.copyWith(color: scheme.hint),
                ),
                const SizedBox(height: AppSpacing.lg),
                SButton(
                  onPressed: onBack,
                  child: const Text('Back to Open PRs'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
