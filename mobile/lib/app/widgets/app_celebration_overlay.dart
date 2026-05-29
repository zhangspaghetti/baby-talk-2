import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Celebration overlay shown after completing a practice session or onboarding.
///
/// 2026-06-01：彩带绘制改用 `confetti` 库（替代自研 `_ConfettiPainter`），
/// 颜色沿用 Warm Paper 色板。外部 API（[child] + [duration]）保持不变。
class AppCelebrationOverlay extends StatefulWidget {
  const AppCelebrationOverlay({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppCelebrationOverlay> createState() => _AppCelebrationOverlayState();
}

class _AppCelebrationOverlayState extends State<AppCelebrationOverlay> {
  late final ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: widget.duration);
    _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 20,
            gravity: 0.25,
            colors: [
              colors.accent,
              colors.success,
              colors.info,
              colors.warning,
            ],
          ),
        ),
      ],
    );
  }
}
