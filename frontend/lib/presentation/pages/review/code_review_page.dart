import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/review/providers/review_provider.dart';
import 'package:sellio_metrics/presentation/pages/review/widgets/review_results_panel.dart';
import 'package:sellio_metrics/presentation/pages/review/widgets/review_selection_panel.dart';

class CodeReviewPage extends StatefulWidget {
  const CodeReviewPage({super.key});

  @override
  State<CodeReviewPage> createState() => _CodeReviewPageState();
}

class _CodeReviewPageState extends State<CodeReviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewProvider>().loadMeta();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          _ReviewHeader(),
          Expanded(
            child: Consumer<ReviewProvider>(
              builder: (context, provider, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReviewSelectionPanel(
                    provider: provider,
                    tabController: _tabController,
                  ),
                  Expanded(
                    child: ReviewResultsPanel(
                      provider: provider,
                      tabController: _tabController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────

class _ReviewHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        border: Border(bottom: BorderSide(color: scheme.stroke, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: SellioColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.searchCode, size: 18, color: scheme.onPrimary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Code Review',
                  style: AppTypography.subtitle.copyWith(
                      color: scheme.title,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text('Powered by Gemini · Production-level analysis',
                  style: AppTypography.caption
                      .copyWith(color: scheme.hint, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
