import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';

/// Post-completion result echo for Home B (Scene-mentor direction).
///
/// Shown after the parent completes a practice. Provides gentle emotional
/// feedback that confirms the value of what they just did.
/// Design spec:
/// - Title: "刚刚完成一次亲子英语时刻"
/// - Xiaohe confirms the action's value
/// - Garden trace grows quietly
class HomeBPracticeResult extends StatelessWidget {
  const HomeBPracticeResult({
    super.key,
    required this.phrase,
    required this.sceneTag,
    this.childName,
    this.onPracticeAgain,
    this.onNextPhrase,
  });

  final String phrase;
  final String sceneTag;
  final String? childName;
  final VoidCallback? onPracticeAgain;
  final VoidCallback? onNextPhrase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Container(
      key: const Key('home-b-practice-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.successSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Completion header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '刚刚完成一次亲子英语时刻',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // What was said
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$phrase"',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.english,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sceneTag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Xiaohe confirmation
          Text(
            '${childName ?? '宝宝'}听到你说这句，就是在学。每次开口都算数。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('home-b-practice-again'),
                  onPressed: onPracticeAgain,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('再说一次'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('home-b-next-phrase'),
                  onPressed: onNextPhrase,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('下一句稍后再来'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
