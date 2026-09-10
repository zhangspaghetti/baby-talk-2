import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';

/// Full-page completion view shown when all phrases in a session are done.
class PracticeCompletionView extends StatelessWidget {
  const PracticeCompletionView({
    super.key,
    required this.spokenCount,
    required this.onRestart,
    required this.onExit,
  });

  /// Number of phrases the user spoke this session (for the summary copy).
  final int spokenCount;

  /// Called when user taps "再来一句" (restart the session).
  final VoidCallback onRestart;

  /// Called when user taps "回到场景" (pop the screen).
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '今天完成了',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          const AppMentorBubble(message: '今天这样就很好。'),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          Text(
            '你说出了 $spokenCount 句。下次打开，小禾会继续给你一句。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayoutConstants.spacingXl),
          FilledButton(onPressed: onRestart, child: const Text('再来一句')),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          TextButton(onPressed: onExit, child: const Text('回到场景')),
        ],
      ),
    );
  }
}
