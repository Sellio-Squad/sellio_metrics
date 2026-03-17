import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// Shared formatter — created once, reused across all instances.
final DateFormat _activityDateFormat = DateFormat('MMM d, yyyy');

class MemberActivityText extends StatelessWidget {
  final DateTime? lastActiveDate;

  const MemberActivityText({super.key, this.lastActiveDate});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final text = lastActiveDate != null
        ? l10n.memberLastActive(
            _activityDateFormat.format(lastActiveDate!),
          )
        : l10n.memberNoActivity;

    return Text(
      text,
      style: AppTypography.caption.copyWith(color: scheme.hint),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
