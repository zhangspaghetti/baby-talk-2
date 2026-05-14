import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Celebration overlay shown after completing a practice session or onboarding.
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

class _AppCelebrationOverlayState extends State<AppCelebrationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeController.forward();
    _particleController.forward().then((_) {
      if (mounted) _fadeController.reverse();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        FadeTransition(
          opacity: _fadeController,
          child: CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _ConfettiPainter(
              animation: _particleController,
              colors: [
                colors.accent,
                colors.success,
                colors.info,
                colors.warning,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.animation, required this.colors})
    : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final _random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    for (var i = 0; i < 40; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final x = _random.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height + 20.0;
      final y = startY + (endY - startY) * progress;
      final offset = Offset(x, y);
      canvas.drawRect(
        Rect.fromCenter(center: offset, width: 6, height: 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
