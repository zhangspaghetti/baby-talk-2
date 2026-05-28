import 'package:flutter/material.dart';

/// Wraps a child widget with a scale-down animation on press.
///
/// Follows the V21 spec: scale(0.95-0.97) on press, 150-200ms ease-out bounce.
/// Respects `MediaQuery.disableAnimations` (prefers-reduced-motion).
class AppScaleButton extends StatefulWidget {
  const AppScaleButton({
    super.key,
    required this.onTap,
    required this.child,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 150),
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scaleDown;
  final Duration duration;

  @override
  State<AppScaleButton> createState() => _AppScaleButtonState();
}

class _AppScaleButtonState extends State<AppScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTapDown: reducedMotion ? null : (_) => _controller.forward(),
      onTapUp: reducedMotion ? null : (_) => _controller.reverse(),
      onTapCancel: reducedMotion ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: reducedMotion
            ? const AlwaysStoppedAnimation(1.0)
            : _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
