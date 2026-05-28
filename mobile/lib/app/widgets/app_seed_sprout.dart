import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Animated seed sprouting into two small leaves.
///
/// V21 spec: grows from bottom, ~1.5s ease-out, uses #3B8577 green
/// and warm brown seed. Respects prefers-reduced-motion by showing
/// the final state immediately.
class AppSeedSprout extends StatefulWidget {
  const AppSeedSprout({
    super.key,
    this.onAnimationComplete,
    this.size = 120,
  });

  final VoidCallback? onAnimationComplete;
  final double size;

  @override
  State<AppSeedSprout> createState() => _AppSeedSproutState();
}

class _AppSeedSproutState extends State<AppSeedSprout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _stemGrow;
  late final Animation<double> _leafLeft;
  late final Animation<double> _leafRight;
  late final Animation<double> _seedFade;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _stemGrow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _leafLeft = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutBack),
      ),
    );

    _leafRight = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.95, curve: Curves.easeOutBack),
      ),
    );

    _seedFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      _controller.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAnimationComplete?.call();
      });
    } else {
      _controller.forward().then((_) {
        if (mounted) {
          widget.onAnimationComplete?.call();
        }
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
    final seedColor = colors.warning.withValues(alpha: 0.7);
    final stemColor = colors.english;
    final leafColor = colors.english;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SproutPainter(
              progress: _controller.value,
              stemGrow: _stemGrow.value,
              leafLeft: _leafLeft.value,
              leafRight: _leafRight.value,
              seedFade: _seedFade.value,
              seedColor: seedColor,
              stemColor: stemColor,
              leafColor: leafColor,
            ),
          );
        },
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.progress,
    required this.stemGrow,
    required this.leafLeft,
    required this.leafRight,
    required this.seedFade,
    required this.seedColor,
    required this.stemColor,
    required this.leafColor,
  });

  final double progress;
  final double stemGrow;
  final double leafLeft;
  final double leafRight;
  final double seedFade;
  final Color seedColor;
  final Color stemColor;
  final Color leafColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final groundY = size.height * 0.85;
    final stemTopY = size.height * 0.2;
    final currentStemTop = groundY - (groundY - stemTopY) * stemGrow;

    // Draw stem
    final stemPaint = Paint()
      ..color = stemColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (stemGrow > 0) {
      canvas.drawLine(
        Offset(cx, groundY),
        Offset(cx, currentStemTop),
        stemPaint,
      );
    }

    // Draw left leaf
    if (leafLeft > 0) {
      final leafPaint = Paint()
        ..color = leafColor.withValues(alpha: leafLeft)
        ..style = PaintingStyle.fill;

      final leafPath = Path();
      final leafBaseY = currentStemTop + 4;
      leafPath.moveTo(cx, leafBaseY);
      leafPath.cubicTo(
        cx - 18 * leafLeft,
        leafBaseY - 14 * leafLeft,
        cx - 22 * leafLeft,
        leafBaseY + 2 * leafLeft,
        cx - 4 * leafLeft,
        leafBaseY + 8 * leafLeft,
      );
      leafPath.close();
      canvas.drawPath(leafPath, leafPaint);
    }

    // Draw right leaf
    if (leafRight > 0) {
      final leafPaint = Paint()
        ..color = leafColor.withValues(alpha: leafRight)
        ..style = PaintingStyle.fill;

      final leafPath = Path();
      final leafBaseY = currentStemTop + 4;
      leafPath.moveTo(cx, leafBaseY);
      leafPath.cubicTo(
        cx + 18 * leafRight,
        leafBaseY - 14 * leafRight,
        cx + 22 * leafRight,
        leafBaseY + 2 * leafRight,
        cx + 4 * leafRight,
        leafBaseY + 8 * leafRight,
      );
      leafPath.close();
      canvas.drawPath(leafPath, leafPaint);
    }

    // Draw seed at base
    if (seedFade > 0) {
      final seedPaint = Paint()
        ..color = seedColor.withValues(alpha: seedFade)
        ..style = PaintingStyle.fill;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, groundY + 2),
          width: 12 * seedFade,
          height: 8 * seedFade,
        ),
        seedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SproutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
