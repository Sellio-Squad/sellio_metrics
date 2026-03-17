import 'package:flutter/material.dart';

/// Pulsing green/red dot — positioned at the top-right of the card.
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

    // Only pulse for active members
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
    final color = widget.isActive ? _activeColor : _inactiveColor;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: _animation.value * 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
