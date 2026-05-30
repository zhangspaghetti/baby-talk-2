import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// 导师气泡形态变体。
///
/// 步骤 2 形态收敛（方案 B：全对齐规范目标态，2026-05-29 设计裁定）：两种气泡
/// 共享统一外壳——28×28 圆角矩形(r12) 暖色渐变头像、气泡 r16 圆角、`warmShadowSm`
/// 阴影、无边框、内边距 12/16、头像间距 8。仅内容（头像前景、标题行、字号、截断、
/// chevron）按场景保留。视觉契约由 `mentor_bubble_form_test.dart` 锁定。
enum AppMentorBubbleVariant {
  /// Onboarding/Practice 引导气泡：头像内为文字 caption，正文 bodyLarge 不限行。
  onboarding,

  /// Home B 建议气泡：头像内为图标，含「小禾」标题、正文 bodyMedium 2 行省略，
  /// 可点击带 chevron。
  home,
}

class AppMentorBubble extends StatelessWidget {
  const AppMentorBubble({
    super.key,
    required this.message,
    this.caption,
    this.trailing,
    this.onTap,
    this.variant = AppMentorBubbleVariant.onboarding,
  });

  final String message;
  final String? caption;
  final Widget? trailing;

  /// 仅 [AppMentorBubbleVariant.home] 使用：点击回调，提供时显示 chevron。
  final VoidCallback? onTap;

  final AppMentorBubbleVariant variant;

  /// 头像暖色渐变（品牌装饰，规范 2.4：#EAD0B6 → #F8E7D4，无对应 token）。
  static const LinearGradient _avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAD0B6), Color(0xFFF8E7D4)],
  );

  /// 共享头像：28×28 圆角矩形 r12（规范 MentorAvatar.Inline）+ 暖色渐变。
  Widget _avatar({required Widget child}) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        gradient: _avatarGradient,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  /// 共享气泡外壳：bgSurface + r16 + warmShadowSm + 无边框 + padding 12/16。
  BoxDecoration _bubbleDecoration(BabyTalkColors colors) {
    return BoxDecoration(
      color: colors.bgSurface,
      borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
      boxShadow: colors.warmShadowSm,
    );
  }

  static const EdgeInsets _bubblePadding = EdgeInsets.symmetric(
    vertical: AppLayoutConstants.spacingSm, // 12
    horizontal: AppLayoutConstants.spacingMd, // 16
  );

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case AppMentorBubbleVariant.onboarding:
        return _buildOnboarding(context);
      case AppMentorBubbleVariant.home:
        return _buildHome(context);
    }
  }

  Widget _buildOnboarding(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l.onboardingMentorMessageSemantics(message),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: _avatar(
              child: Text(
                l.onboardingMentorCaption,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppLayoutConstants.spacingXs),
          Expanded(
            child: Container(
              padding: _bubblePadding,
              decoration: _bubbleDecoration(colors),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (caption != null) ...[
                          Text(
                            caption!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.accentDark,
                            ),
                          ),
                          const SizedBox(height: AppLayoutConstants.spacingXs),
                        ],
                        Text(
                          message,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: AppLayoutConstants.spacingSm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Semantics(
      button: onTap != null,
      label: '小禾建议: $message',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: const Key('home-b-mentor-bubble'),
          width: double.infinity,
          padding: _bubblePadding,
          decoration: _bubbleDecoration(colors),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Xiaohe avatar：图标前景用 accentDark 保证浅渐变上的对比度（WCAG AA）
              ExcludeSemantics(
                child: _avatar(
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: colors.accentDark,
                  ),
                ),
              ),
              const SizedBox(width: AppLayoutConstants.spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '小禾',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.accentDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
