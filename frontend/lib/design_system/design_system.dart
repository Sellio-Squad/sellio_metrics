/// Sellio Metrics — Design System
///
/// Barrel file that re-exports all design system components and tokens.
/// Presentation layer imports ONLY this file — never hux directly.
library;

// ─── Tokens (theme, colors, spacing, etc.) ──────────────────
export '../core/theme/sellio_colors.dart';
export '../core/theme/app_spacing.dart';
export '../core/theme/app_radius.dart';
export '../core/theme/app_typography.dart';

// ─── S* wrapper components ──────────────────────────────────
export 'components/s_avatar.dart';
export 'components/s_badge.dart';
export 'components/s_button.dart';
export 'components/s_card.dart';
export 'components/s_date_picker.dart';
export 'components/s_input.dart';
export 'components/s_loading.dart';
export 'components/s_progress.dart';
export 'components/s_sidebar.dart';
export 'components/s_switch.dart';

// ─── Icons (re-exported for convenience) ─────────────────────
export 'package:hux/hux.dart' show LucideIcons;
