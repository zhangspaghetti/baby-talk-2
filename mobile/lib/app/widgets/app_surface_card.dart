import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// 卡片高度/阴影变体（规范 §2.11，2026-05-29 方案 B 收敛）。
enum AppSurfaceCardVariant {
  /// 规范 Static：列表项 / 信息卡，`--shadow-sm`（`warmShadowSm`）。
  standard,

  /// 规范 Elevated：浮起主卡片，`--shadow-md`（`warmShadowMd`）。
  elevated,

  /// 规范 Borderless：内联 / 嵌套内容，无阴影。
  borderless,
}

/// 通用表面卡片。
///
/// 2026-05-29 方案 B 收敛至规范 §2.11 目标态：**默认 r16 + 无边框 + padding
/// 20/24 + 按 [variant] 阴影**。裸参数（[borderRadius] / [borderColor] /
/// [boxShadow] / [padding]）保留向后兼容，提供时覆盖变体默认值。
class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.variant = AppSurfaceCardVariant.standard,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppLayoutConstants.spacingLg, // 20
      vertical: AppLayoutConstants.spacingXl, // 24
    ),
    this.width = double.infinity,
    this.borderRadius = AppLayoutConstants.cardRadius, // 16
    this.backgroundColor,
    this.borderColor,
    this.boxShadow,
  });

  final Widget child;

  /// 阴影/高度变体；[boxShadow] 不为 null 时被覆盖。
  final AppSurfaceCardVariant variant;

  final EdgeInsetsGeometry padding;
  final double? width;
  final double borderRadius;
  final Color? backgroundColor;

  /// 边框颜色；默认 null = 无边框（规范目标态）。提供时绘制 `Border.all`。
  final Color? borderColor;

  /// 显式阴影；为 null 时按 [variant] 推导。传 `const []` 可强制无阴影。
  final List<BoxShadow>? boxShadow;

  List<BoxShadow> _shadowFor(BabyTalkColors colors) {
    switch (variant) {
      case AppSurfaceCardVariant.standard:
        return colors.warmShadowSm;
      case AppSurfaceCardVariant.elevated:
        return colors.warmShadowMd;
      case AppSurfaceCardVariant.borderless:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.bgSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: boxShadow ?? _shadowFor(colors),
      ),
      child: child,
    );
  }
}
