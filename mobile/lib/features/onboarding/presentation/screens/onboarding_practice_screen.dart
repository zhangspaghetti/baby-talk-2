import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/widgets/reaction_button.dart';

class OnboardingPracticeScreen extends ConsumerWidget {
  const OnboardingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final phrase = notifier.currentPhrase;

    if (scene == null || phrase == null) {
      return const Scaffold(
        body: Center(child: Text('场景未选择')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingSm,
                    vertical: AppLayoutConstants.spacingXs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          '${scene.label} / 一句就够',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/onboarding/complete');
                        },
                        child: const Text('结束'),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: AppLayoutConstants.screenPadding,
                    children: [
                      AppMentorBubble(message: scene.mentorBubbleCopy),
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      // Phrase display (no border)
                      _PhraseDisplay(phrase: phrase),
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      // Reaction area
                      if (notifier.showReactionPicker)
                        _ReactionArea(notifier: notifier),
                    ],
                  ),
                ),
                // Bottom buttons
                _BottomActions(notifier: notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhraseDisplay extends StatelessWidget {
  const _PhraseDisplay({required this.phrase});

  final dynamic phrase; // ScenePhrase

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scene pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
          ),
          child: Text(
            phrase.scene.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.accentDark,
            ),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        // English phrase
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                phrase.english,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 32,
                  height: 1.3,
                  color: colors.english,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.volume_up_outlined,
                size: 20,
                color: colors.textSecondary,
              ),
              onPressed: () {
                // TODO: TTS playback - connects to backend TTS service
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        // Chinese translation
        Text(
          phrase.chinese,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ReactionArea extends StatelessWidget {
  const _ReactionArea({required this.notifier});

  final dynamic notifier; // OnboardingSessionNotifier

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '已保存本句',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        // Reaction buttons
        ...BabyReaction.values.map((reaction) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppLayoutConstants.spacingSm,
            ),
            child: ReactionButton(
              reaction: reaction,
              onTap: () => notifier.selectReaction(reaction),
            ),
          );
        }),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        // Skip reaction link
        Center(
          child: TextButton(
            onPressed: () => notifier.skipReaction(),
            child: const Text('跳过，下一句'),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.notifier});

  final dynamic notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionNotifier = ref.read(onboardingSessionProvider.notifier);

    if (notifier.showReactionPicker) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: AppLayoutConstants.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppScaleButton(
            scaleDown: 0.97,
            onTap: () {
              HapticFeedback.mediumImpact();
              sessionNotifier.recordSaid();
            },
            child: const ElevatedButton(
              key: Key('onboarding-said-button'),
              onPressed: null,
              child: Text('说完了'),
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: notifier.phrasePoolExhausted
                    ? null
                    : () => sessionNotifier.swapPhrase(),
                child: Text(
                  notifier.phrasePoolExhausted ? '句子都试过了' : '换一句',
                ),
              ),
              const SizedBox(width: AppLayoutConstants.spacingMd),
              TextButton(
                onPressed: () {
                  context.push('/onboarding/complete');
                },
                child: const Text('结束'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
