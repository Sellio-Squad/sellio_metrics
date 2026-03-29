// ─── Widget: Create Schedule Panel ────────────────────────────────────────────
//
// Inline form for creating a new RegularMeetingSchedule.
// Presented as an animated expandable card within RegularMeetingsSection.

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';

class CreateSchedulePanel extends StatefulWidget {
  final Future<bool> Function(RegularMeetingSchedule) onCreate;
  final VoidCallback onCancel;

  const CreateSchedulePanel({
    super.key,
    required this.onCreate,
    required this.onCancel,
  });

  @override
  State<CreateSchedulePanel> createState() => _CreateSchedulePanelState();
}

class _CreateSchedulePanelState extends State<CreateSchedulePanel> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dayTimeCtrl = TextEditingController();
  bool _isSaving = false;
  String? _errorMsg;

  // Selected values
  String _selectedDuration = '30 min';
  String _selectedRecurrence = 'Weekly';
  Color _selectedColor = const Color(0xFF6366F1);
  IconData _selectedIcon = Icons.groups_rounded;

  static const _durations = ['15 min', '30 min', '45 min', '1 hr', '2 hr'];
  static const _recurrences = ['Daily', 'Weekly', 'Biweekly', 'Monthly'];

  static const _colorOptions = [
    Color(0xFF6366F1), // indigo
    Color(0xFF0EA5E9), // blue
    Color(0xFF10B981), // green
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // purple
    Color(0xFF6B7280), // gray
  ];

  static const _iconOptions = [
    Icons.groups_rounded,
    Icons.refresh_rounded,
    Icons.calendar_month_rounded,
    Icons.code_rounded,
    Icons.forum_rounded,
    Icons.rocket_launch_rounded,
    Icons.lightbulb_rounded,
    Icons.analytics_rounded,
    Icons.bug_report_rounded,
    Icons.school_rounded,
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dayTimeCtrl.dispose();
    super.dispose();
  }

  Duration _parseDuration(String label) {
    switch (label) {
      case '15 min': return const Duration(minutes: 15);
      case '30 min': return const Duration(minutes: 30);
      case '45 min': return const Duration(minutes: 45);
      case '1 hr':   return const Duration(hours: 1);
      case '2 hr':   return const Duration(hours: 2);
      default:       return const Duration(minutes: 30);
    }
  }

  String _recurrenceRule(String label) {
    switch (label) {
      case 'Daily':    return 'FREQ=DAILY';
      case 'Weekly':   return 'FREQ=WEEKLY';
      case 'Biweekly': return 'FREQ=WEEKLY;INTERVAL=2';
      case 'Monthly':  return 'FREQ=MONTHLY';
      default:         return 'FREQ=WEEKLY';
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMsg = 'Meeting title is required.');
      return;
    }
    setState(() { _isSaving = true; _errorMsg = null; });

    final schedule = RegularMeetingSchedule(
      id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: _descCtrl.text.trim().isEmpty
          ? 'Recurring team meeting.'
          : _descCtrl.text.trim(),
      dayTime: _dayTimeCtrl.text.trim().isEmpty
          ? _selectedRecurrence
          : _dayTimeCtrl.text.trim(),
      durationLabel: _selectedDuration,
      recurrenceLabel: _selectedRecurrence,
      icon: _selectedIcon,
      accentColor: _selectedColor,
      startTime: DateTime.now(),
      duration: _parseDuration(_selectedDuration),
      recurrenceRule: _recurrenceRule(_selectedRecurrence),
    );

    final ok = await widget.onCreate(schedule);
    if (!ok && mounted) {
      setState(() {
        _errorMsg = 'Failed to create schedule.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(Icons.add_rounded, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'New Meeting Schedule',
                style: AppTypography.subtitle.copyWith(
                  color: scheme.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: scheme.hint),
                onPressed: widget.onCancel,
                splashRadius: 18,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Title
          _Label('Meeting Title'),
          const SizedBox(height: AppSpacing.xs),
          _Field(
            controller: _titleCtrl,
            hint: 'e.g., Design Review',
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Description
          _Label('Description'),
          const SizedBox(height: AppSpacing.xs),
          _Field(
            controller: _descCtrl,
            hint: 'Short description of the meeting purpose',
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Day/Time label
          _Label('Day & Time (display label)'),
          const SizedBox(height: AppSpacing.xs),
          _Field(
            controller: _dayTimeCtrl,
            hint: 'e.g., Wednesday, 3:00 PM',
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Duration + Recurrence
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            final durationPicker = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Duration'),
                const SizedBox(height: AppSpacing.xs),
                _DropdownPicker<String>(
                  value: _selectedDuration,
                  items: _durations,
                  label: (v) => v,
                  onChanged: (v) => setState(() => _selectedDuration = v),
                ),
              ],
            );
            final recurrencePicker = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('Recurrence'),
                const SizedBox(height: AppSpacing.xs),
                _DropdownPicker<String>(
                  value: _selectedRecurrence,
                  items: _recurrences,
                  label: (v) => v,
                  onChanged: (v) => setState(() => _selectedRecurrence = v),
                ),
              ],
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: durationPicker),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: recurrencePicker),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                durationPicker,
                const SizedBox(height: AppSpacing.md),
                recurrencePicker,
              ],
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // ── Color picker
          _Label('Colour'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: _colorOptions.map((c) {
              final selected = c.value == _selectedColor.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.title : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6)]
                        : [],
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Icon picker
          _Label('Icon'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _iconOptions.map((icon) {
              final selected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? _selectedColor.withValues(alpha: 0.15)
                        : scheme.surfaceLow,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                      color: selected
                          ? _selectedColor.withValues(alpha: 0.4)
                          : scheme.stroke,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? _selectedColor : scheme.hint,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Error
          if (_errorMsg != null) ...[
            Text(
              _errorMsg!,
              style: AppTypography.caption.copyWith(color: SellioColors.red),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // ── Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SButton(
                variant: SButtonVariant.ghost,
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              SButton(
                variant: SButtonVariant.primary,
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16),
                          SizedBox(width: AppSpacing.xs),
                          Text('Add Schedule'),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: context.colors.hint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        isDense: true,
      ),
      style: AppTypography.body.copyWith(
        color: scheme.title,
        fontSize: 14,
      ),
    );
  }
}

class _DropdownPicker<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final void Function(T) onChanged;

  const _DropdownPicker({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: scheme.hint),
          dropdownColor: scheme.surface,
          style: AppTypography.body.copyWith(color: scheme.title, fontSize: 14),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(label(item)),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
