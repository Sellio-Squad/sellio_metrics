import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/meetings/providers/meetings_provider.dart';

class CreateMeetingPanel extends StatefulWidget {
  final VoidCallback onCreated;
  final VoidCallback onCancel;

  const CreateMeetingPanel({
    super.key,
    required this.onCreated,
    required this.onCancel,
  });

  @override
  State<CreateMeetingPanel> createState() => _CreateMeetingPanelState();
}

class _CreateMeetingPanelState extends State<CreateMeetingPanel>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));

    _entryController.forward();

    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MeetingsProvider>();
    final success = await provider.createMeeting(_titleController.text.trim());

    if (success && mounted) {
      widget.onCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final isCreating = context.watch<MeetingsProvider>().isCreating;
    final error = context.watch<MeetingsProvider>().error;
    final authUrl = context.watch<MeetingsProvider>().authUrl;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: scheme.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Header accent
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: scheme.primary.withOpacity(0.1),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Icon(
                              LucideIcons.plus,
                              size: 16,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.createMeeting,
                                style: AppTypography.title.copyWith(
                                  fontSize: 18,
                                  color: scheme.title,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Generate a Google Meet link and track live attendance.',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: widget.onCancel,
                            icon: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: scheme.hint,
                            ),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Input + Actions row (inline layout)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 600;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    scheme, l10n, isCreating,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _buildSubmitButton(
                                  scheme, l10n, isCreating,
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTextField(scheme, l10n, isCreating),
                              const SizedBox(height: AppSpacing.md),
                              _buildSubmitButton(scheme, l10n, isCreating),
                            ],
                          );
                        },
                      ),

                      // ── Error state
                      if (error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ErrorBanner(
                          error: error,
                          authUrl: authUrl,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    dynamic scheme,
    AppLocalizations l10n,
    bool isCreating,
  ) {
    return TextFormField(
      controller: _titleController,
      focusNode: _focusNode,
      enabled: !isCreating,
      textInputAction: TextInputAction.go,
      decoration: InputDecoration(
        labelText: l10n.meetingName,
        hintText: l10n.meetingNameHint,
        prefixIcon: Icon(
          LucideIcons.type,
          size: 18,
          color: scheme.hint,
        ),
        filled: true,
        fillColor: scheme.surfaceLow,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Please enter a meeting name';
        }
        return null;
      },
      onFieldSubmitted: (_) => _submit(),
    );
  }

  Widget _buildSubmitButton(
    dynamic scheme,
    AppLocalizations l10n,
    bool isCreating,
  ) {
    return SizedBox(
      height: 48,
      child: SButton(
        variant: SButtonVariant.primary,
        onPressed: isCreating ? null : _submit,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isCreating
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.sparkles, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.createMeeting),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Error Banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  final String? authUrl;

  const _ErrorBanner({required this.error, this.authUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: SellioColors.red.withOpacity(0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: SellioColors.red.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.alertCircle,
            size: 16,
            color: SellioColors.red,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  error,
                  style: AppTypography.caption.copyWith(
                    color: SellioColors.red,
                    height: 1.4,
                  ),
                ),
                if (authUrl != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SButton(
                    variant: SButtonVariant.primary,
                    size: SButtonSize.small,
                    onPressed: () => launchUrl(Uri.parse(authUrl!)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.chrome, size: 14),
                        const SizedBox(width: AppSpacing.xs),
                        const Text('Sign in with Google'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}