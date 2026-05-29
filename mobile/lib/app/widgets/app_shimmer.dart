import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton screen loading placeholder that replaces 4px gray bars.
///
/// 2026-06-01：微光引擎改用 `skeletonizer`（替代自研 `AnimatedBuilder`），
/// 基色/高亮沿用 Warm Paper 令牌。API（[width]/[height]/[borderRadius]）保持不变。
class AppShimmer extends StatelessWidget {
  const AppShimmer({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = 12,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Skeletonizer.zone(
      effect: ShimmerEffect(
        baseColor: colors.outlineSoft.withValues(alpha: 0.10),
        highlightColor: colors.outlineSoft.withValues(alpha: 0.22),
      ),
      child: Bone(
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
