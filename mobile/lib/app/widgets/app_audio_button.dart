import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// 共享发音/播放按钮的「外观层」（规范 §AudioButton，2026-05-29 收敛）。
///
/// 仅负责呈现：胶囊点击区（圆角 9999）、`minTouchTarget` 最小触达高度、
/// 18px 次要色图标、播放中文案。所有状态判断（TTS/播放模式、播放中、可点性、
/// 语义 key 与回调选择）保留在调用点，避免把播放状态机耦合进共享组件。
class AppAudioButton extends StatelessWidget {
  const AppAudioButton({
    super.key,
    required this.semanticsLabel,
    required this.icon,
    this.buttonKey,
    this.onTap,
    this.isPlaying = false,
    this.playingLabel = '播放中',
  });

  /// 无障碍标签，例如「朗读发音」/「播放发音」。
  final String semanticsLabel;

  /// 当前应展示的图标，由调用点根据模式/播放态决定。
  final IconData icon;

  /// 点击区的语义 key（落在内部 InkWell 上，保持既有测试定位不变）。
  final Key? buttonKey;

  /// 点击回调；为 null 时按钮不可点。
  final VoidCallback? onTap;

  /// 是否处于播放中（控制图标外的「播放中」文案）。
  final bool isPlaying;

  /// 播放中提示文案。
  final String playingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppLayoutConstants.minTouchTarget,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: colors.textSecondary),
                  if (isPlaying) ...[
                    const SizedBox(width: 4),
                    Text(
                      playingLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
