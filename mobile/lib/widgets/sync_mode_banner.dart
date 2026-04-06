import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SyncModeBanner extends StatelessWidget {
  const SyncModeBanner.offline({super.key, this.compact = false})
    : icon = Icons.portable_wifi_off_outlined,
      message = '没有网络，部分功能暂时休息。恢复联网后自动同步。';

  const SyncModeBanner.local({super.key, this.compact = false})
    : icon = Icons.sync_problem_outlined,
      message = '远端同步暂时不可用，当前先在本地模式继续。稍后会自动重试。';

  final IconData icon;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppPalette.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
