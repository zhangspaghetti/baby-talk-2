import 'package:flutter/material.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';

/// Xiaohe mentor suggestion bubble for Home B.
///
/// A compact bubble that provides contextual guidance, e.g.,
/// "这句适合睡前收尾，不像命令，更像邀请宝宝一起完成。"
/// Limited to 2 lines max per design spec.
///
/// 步骤 2 结构统一后，本组件为 [AppMentorBubble] 的薄包装，
/// 委托至 [AppMentorBubbleVariant.home] 形态，视觉与行为保持不变。
class HomeBMentorBubble extends StatelessWidget {
  const HomeBMentorBubble({
    super.key,
    required this.message,
    this.onTap,
  });

  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppMentorBubble(
      message: message,
      onTap: onTap,
      variant: AppMentorBubbleVariant.home,
    );
  }
}
