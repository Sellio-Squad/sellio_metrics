import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class AboutFooterCta extends StatelessWidget {
  const AboutFooterCta({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxxl + AppSpacing.xl,
      ),
      // ════════════════════════════════════════════════
      // FIX: scheme.surface matches the Scaffold bg
      // surfaceLow = white, surface = #F8F8F8
      // ════════════════════════════════════════════════
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.stroke, width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primaryVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: scheme.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Ready to Build the Future\nof E-Commerce?',
                style: AppTypography.heading.copyWith(
                  color: scheme.title,
                  fontSize: 26,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Join the Sellio team and help shape a sustainable, '
                    'AI-powered marketplace for the MENA region.',
                style: AppTypography.body.copyWith(
                  color: scheme.hint,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  _CtaButton(
                    label: 'Get in Touch',
                    icon: Icons.mail_outline_rounded,
                    isPrimary: true,
                    scheme: scheme,
                    onPressed: () {},
                  ),
                  _CtaButton(
                    label: 'View Roadmap',
                    icon: Icons.map_outlined,
                    isPrimary: false,
                    scheme: scheme,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                '© ${DateTime.now().year} Sellio — All rights reserved.',
                style: AppTypography.caption.copyWith(
                  color: scheme.hint.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final SellioColorScheme scheme;
  final VoidCallback onPressed;

  const _CtaButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.scheme,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? scheme.primary : Colors.transparent,
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.mdAll,
        hoverColor: isPrimary
            ? scheme.primary.withValues(alpha: 0.85)
            : scheme.stroke.withValues(alpha: 0.3),
        splashColor: scheme.primary.withValues(alpha: 0.05),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          decoration: isPrimary
              ? null
              : BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: scheme.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? scheme.onPrimary : scheme.body,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isPrimary ? scheme.onPrimary : scheme.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}