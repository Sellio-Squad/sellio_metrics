import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/about/about_section_header.dart';

class AboutTechStackSection extends StatelessWidget {
  const AboutTechStackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final techItems = [
      _TechItem(
        l10n.techFlutter,
        l10n.techFlutterRole,
        LucideIcons.smartphone,
        const Color(0xFF027DFD),
      ),
      _TechItem(
        l10n.techKotlin,
        l10n.techKotlinRole,
        LucideIcons.server,
        const Color(0xFF7F52FF),
      ),
      _TechItem(
        l10n.techGithubActions,
        l10n.techGithubActionsRole,
        LucideIcons.gitBranch,
        const Color(0xFF2088FF),
      ),
      _TechItem(
        l10n.techFirebase,
        l10n.techFirebaseRole,
        LucideIcons.database,
        const Color(0xFFFFCA28),
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionHeader(
            title: l10n.aboutTechStack,
            icon: Icons.code,
            subtitle: 'Built with modern, scalable technologies.',
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  // ─── HORIZONTAL LAYOUT: shorter cards ────────
                  mainAxisExtent: 80,
                ),
                itemCount: techItems.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) =>
                    _TechCard(tech: techItems[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TechCard extends StatefulWidget {
  final _TechItem tech;
  const _TechCard({required this.tech});

  @override
  State<_TechCard> createState() => _TechCardState();
}

class _TechCardState extends State<_TechCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _isHovered ? scheme.primaryVariant : scheme.surfaceLow,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: _isHovered
                ? widget.tech.color.withValues(alpha: 0.3)
                : scheme.stroke,
          ),
        ),
        // ─── HORIZONTAL ROW layout (no overflow) ─────────
        child: Row(
          children: [
            // Icon with tinted bg
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.tech.color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Center(
                child: Icon(
                  widget.tech.icon,
                  color: widget.tech.color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.tech.name,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.title,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.tech.role,
                    style: AppTypography.caption.copyWith(
                      color: scheme.hint,
                      fontSize: 11,
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

class _TechItem {
  final String name;
  final String role;
  final IconData icon;
  final Color color;
  const _TechItem(this.name, this.role, this.icon, this.color);
}