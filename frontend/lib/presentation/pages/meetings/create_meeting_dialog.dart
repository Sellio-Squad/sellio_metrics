import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';

class CreateMeetingDialog extends StatefulWidget {
  const CreateMeetingDialog({super.key});

  @override
  State<CreateMeetingDialog> createState() => _CreateMeetingDialogState();
}

class _CreateMeetingDialogState extends State<CreateMeetingDialog> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MeetingsProvider>();
    final success = await provider.createMeeting(_titleController.text.trim());

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final isCreating = context.watch<MeetingsProvider>().isCreating;
    final error = context.watch<MeetingsProvider>().error;
    final authUrl = context.watch<MeetingsProvider>().authUrl;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.createMeeting,
                style: AppTypography.title.copyWith(
                  fontSize: 22,
                  color: scheme.title,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Generate a Google Meet link and track live attendance instantly.',
                style: AppTypography.body.copyWith(color: scheme.hint),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _titleController,
                enabled: !isCreating,
                decoration: InputDecoration(
                  labelText: l10n.meetingName,
                  hintText: l10n.meetingNameHint,
                  prefixIcon: const Icon(LucideIcons.type),
                  border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  error,
                  style: AppTypography.caption.copyWith(
                    color: SellioColors.red,
                  ),
                ),
                if (authUrl != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SButton(
                    variant: SButtonVariant.primary,
                    onPressed: () => launchUrl(Uri.parse(authUrl)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.chrome, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('Sign in with Google'),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SButton(
                    variant: SButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SButton(
                    variant: SButtonVariant.primary,
                    onPressed: isCreating ? null : _submit,
                    child: isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.createMeeting),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
