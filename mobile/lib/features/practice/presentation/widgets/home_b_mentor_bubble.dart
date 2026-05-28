import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Xiaohe mentor suggestion bubble for Home B.
///
/// A compact bubble that provides contextual guidance, e.g.,
/// "这句适合睡前收尾，不像命令，更像邀请宝宝一起完成。"
/// Limited to 2 lines max per design spec.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Small Xiaohe avatar dot
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.accentDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
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
