import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

class MemberActivityText extends StatelessWidget {
  final DateTime? lastActiveDate;

  const MemberActivityText({super.key, this.lastActiveDate});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final text = lastActiveDate != null
        ? l10n.memberLastActive(_dateFormat.format(lastActiveDate!))
        : l10n.memberNoActivity;

    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: scheme.hint,
        fontSize: 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
