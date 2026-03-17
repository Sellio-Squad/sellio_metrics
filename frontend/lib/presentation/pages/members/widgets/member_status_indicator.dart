import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class MemberStatusIndicator extends StatefulWidget {
  final bool isActive;

  const MemberStatusIndicator({
    super.key,
    required this.isActive,
  });

  @override
  State<MemberStatusIndicator> createState() =>
      _MemberStatusIndicatorState();
}

class _MemberStatusIndicatorState extends State<MemberStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  static const _activeColor = Color(0xFF22C55E);
  static const _inactiveColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MemberStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = widget.isActive ? _activeColor : _inactiveColor;
    final label = widget.isActive
        ? l10n.memberStatusActive
        : l10n.memberStatusInactive;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 6),

        // Animated dot
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: widget.isActive
                    ? [
                  BoxShadow(
                    color: color.withValues(
                      alpha: _animation.value * 0.6,
                    ),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}