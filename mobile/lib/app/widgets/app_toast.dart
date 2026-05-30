import 'package:flutter/material.dart';

/// 共享 Toast/SnackBar 入口（规范 §Toast，2026-05-29 收敛）。
///
/// 外观完全沿用主题 `snackBarTheme`（bgSurface 背景、bodyMedium/textPrimary
/// 文字、圆角 `cardRadius`、`floating` 行为），调用点无需重复设置 shape /
/// behavior，避免出现与主题不一致的硬编码圆角。
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  Duration? duration,
}) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}
