import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

class CountdownProgressBar extends StatefulWidget {
  const CountdownProgressBar({
    super.key,
    required this.duration,
    required this.onComplete,
  });

  final Duration duration;
  final VoidCallback onComplete;

  @override
  State<CountdownProgressBar> createState() => _CountdownProgressBarState();
}

class _CountdownProgressBarState extends State<CountdownProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      widget.onComplete();
    } else {
      _controller.forward().then((_) {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return LinearProgressIndicator(
          value: _controller.value,
          backgroundColor: colors.bgSunken,
          valueColor: AlwaysStoppedAnimation(colors.accent),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        );
      },
    );
  }
}
