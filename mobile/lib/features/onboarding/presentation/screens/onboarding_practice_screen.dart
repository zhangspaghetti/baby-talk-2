import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/reaction_button.dart';

class OnboardingPracticeScreen extends ConsumerWidget {
  const OnboardingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final phrase = notifier.currentPhrase;

    if (scene == null || phrase == null) {
      return const Scaffold(
        body: Center(child: Text('场景未选择')),
      );
    }

    final theme = Theme.of(context);
    final colors = context.appColors;

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
                          '${scene.label} / ${l.onboardingV21PracticeSubtitle}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/onboarding/complete');
                        },
                        child: Text(l.onboardingV21EndButton),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    padding: AppLayoutConstants.screenPadding,
                    children: [
                      // Progress indicator
                      Center(
                        child: Text(
                          '${notifier.currentPhraseIndex} / ${notifier.totalPhrasesInScene}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      AppMentorBubble(message: scene.mentorBubbleCopy),
                      const SizedBox(height: AppLayoutConstants.spacingXl),
                      // Phrase display (centered)
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

  final ScenePhrase phrase;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // English phrase (centered, large)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                phrase.english,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 26,
                  height: 1.3,
                  color: colors.english,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.volume_up_outlined,
                size: 22,
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
        // Chinese translation (centered)
        Text(
          phrase.chinese,
          textAlign: TextAlign.center,
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

  final OnboardingSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.onboardingV21Saved,
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
            child: Text(l.onboardingV21SkipReaction),
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final sessionNotifier = ref.read(onboardingSessionProvider.notifier);

    if (notifier.showReactionPicker) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: AppLayoutConstants.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CTA button: "我说了 ✨" with heart icon
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              key: const Key('onboarding-said-button'),
              onPressed: () {
                HapticFeedback.mediumImpact();
                sessionNotifier.recordSaid();
              },
              icon: const Text('❤️', style: TextStyle(fontSize: 18)),
              label: Text(
                '我说了 ✨',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
          // Helper text
          Text(
            '等你说完再点哦 →',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
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
                  notifier.phrasePoolExhausted
                      ? l.onboardingV21PhrasesExhausted
                      : l.onboardingV21SwapButton,
                ),
              ),
              const SizedBox(width: AppLayoutConstants.spacingMd),
              TextButton(
                onPressed: () {
                  context.push('/onboarding/complete');
                },
                child: Text(l.onboardingV21EndButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
