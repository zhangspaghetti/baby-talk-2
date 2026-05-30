import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// 共享英文短语主显示（规范 §2.6，2026-05-29 方案 B 收敛）。
///
/// 英文短语是 BabyTalk 最核心的视觉元素，所有页面的**主显示**统一规格：
/// **Fraunces 32px / 字重 500 / 行高 1.2 / `colors.english`**（即主题
/// `displayMedium` + english 前景色）。原 onboarding 44px、Home 30px、
/// practice/garden 28px、discover 24px 等不一致字号统一收敛至 32px（M1）。
///
/// 仅用于短语主显示；小号强调标签 / pill / 进度条等 `colors.english` 用法
/// 不属本组件范畴，保持原样。紧凑预览（如 MiniSeedCard）可保留规范允许的
/// 最小号 24px（Title 2），不强制走本组件。
class AppEnglishPhrase extends StatelessWidget {
  const AppEnglishPhrase(
    this.text, {
    super.key,
    this.maxLines,
    this.textAlign,
    this.overflow,
  });

  /// 英文短语文本。
  final String text;

  final int? maxLines;
  final TextAlign? textAlign;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Text(
      text,
      maxLines: maxLines,
      textAlign: textAlign,
      overflow: overflow,
      style: Theme.of(
        context,
      ).textTheme.displayMedium?.copyWith(color: colors.english),
    );
  }
}
