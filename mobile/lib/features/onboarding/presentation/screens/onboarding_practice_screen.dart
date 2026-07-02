import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';

class OnboardingPracticeScreen extends ConsumerWidget {
  const OnboardingPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final phrase = notifier.currentPhrase;

    if (scene == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/onboarding/scene');
        }
      });
      return const OnboardingWarmScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // When phrase pool is exhausted, navigate to complete screen
    if (phrase == null) {
      // Use addPostFrameCallback to avoid building during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.push('/onboarding/complete');
        }
      });
      return const OnboardingWarmScaffold(child: Center(child: Text('练习完成')));
    }

    return OnboardingWarmScaffold(
      bottomNavigationBar: _BottomActionBar(notifier: notifier),
      child: Column(
        children: [
          _PracticeHeader(
            scene: scene,
            showEndAction: !notifier.showReactionPicker,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              children: [
                if (notifier.showReactionPicker) ...[
                  OnboardingProgressBar(
                    current: notifier.currentPhraseIndex,
                    total: notifier.totalPhrasesInScene,
                  ),
                  const SizedBox(height: 48),
                  const OnboardingMentorBubble(
                    message: '你说得真好，\n宝宝一定感受到了你的爱 ♡',
                    assetName: OnboardingAssets.mentorPraying,
                  ),
                  const SizedBox(height: 48),
                ] else ...[
                  const SizedBox(height: 38),
                  OnboardingMentorBubble(
                    message: _mentorCopyFor(scene),
                    assetName: OnboardingAssets.mentor,
                  ),
                  const SizedBox(height: 36),
                ],
                _PhraseDisplay(
                  phrase: phrase,
                  scene: scene,
                  showScenePill: !notifier.showReactionPicker,
                ),
                if (notifier.showReactionPicker) ...[
                  const SizedBox(height: 42),
                  _ReactionArea(notifier: notifier),
                ] else ...[
                  const SizedBox(height: 58),
                  Text(
                    '${notifier.currentPhraseIndex} / ${notifier.totalPhrasesInScene}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.appColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _mentorCopyFor(PracticeScene scene) {
    switch (scene) {
      case PracticeScene.bath:
        return '太棒了！洗澡时间是\n和宝宝亲密交流的好时机。';
      default:
        return scene.mentorBubbleCopy;
    }
  }
}

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({required this.scene, required this.showEndAction});

  final PracticeScene scene;
  final bool showEndAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: colors.textPrimary),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              showEndAction ? '' : scene.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: showEndAction
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => context.push('/onboarding/complete'),
                    child: Text(
                      '稍后再说',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PhraseDisplay extends StatelessWidget {
  const _PhraseDisplay({
    required this.phrase,
    required this.scene,
    required this.showScenePill,
  });

  final ScenePhrase phrase;
  final PracticeScene scene;
  final bool showScenePill;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showScenePill) ...[
          _ScenePill(scene: scene),
          const SizedBox(height: 28),
        ],
        Text(
          phrase.english,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: 33,
            height: 1.28,
            color: colors.english,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          phrase.chinese,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _phoneticFor(phrase.phraseId),
          textAlign: TextAlign.center,
          style: AppTheme.monoStyle.copyWith(
            color: colors.textMuted,
            fontSize: 13,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        IconButton(
          icon: Icon(Icons.volume_up_outlined, color: colors.textPrimary),
          onPressed: () {
            HapticFeedback.selectionClick();
          },
          iconSize: 28,
        ),
      ],
    );
  }

  String _phoneticFor(String phraseId) {
    switch (phraseId) {
      case 'bath_1':
        return '[ ai lʌv bæθ taim wið ju ]';
      case 'bath_2':
        return '[ jur sou wɔrm ænd klin ]';
      default:
        return '[ ${phrase.english.toLowerCase()} ]';
    }
  }
}

class _ScenePill extends StatelessWidget {
  const _ScenePill({required this.scene});

  final PracticeScene scene;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.englishSoft.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            scene.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.english,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          const Text('🛁', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _ReactionArea extends StatelessWidget {
  const _ReactionArea({required this.notifier});

  final OnboardingSessionNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '宝宝有什么反应呢？（可选）',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: BabyReaction.values.map((reaction) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ReactionCard(
                  reaction: reaction,
                  onTap: () => notifier.selectReaction(reaction),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ReactionCard extends StatelessWidget {
  const _ReactionCard({required this.reaction, required this.onTap});

  final BabyReaction reaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaleButton(
      onTap: onTap,
      scaleDown: 0.96,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9CBA8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _reactionIcon(reaction),
            const SizedBox(height: 7),
            Text(
              reaction.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.appColors.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.25,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reactionIcon(BabyReaction reaction) {
    switch (reaction) {
      case BabyReaction.responded:
        return const OnboardingAssetImage(
          OnboardingAssets.happy,
          width: 34,
          height: 34,
        );
      case BabyReaction.calmed:
        return const OnboardingAssetImage(
          OnboardingAssets.feeding,
          width: 38,
          height: 34,
        );
      case BabyReaction.noResponse:
        return const OnboardingAssetImage(
          OnboardingAssets.neutral,
          width: 34,
          height: 34,
        );
    }
  }
}

class _BottomActionBar extends ConsumerWidget {
  const _BottomActionBar({required this.notifier});

  final OnboardingSessionNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final sessionNotifier = ref.read(onboardingSessionProvider.notifier);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayoutConstants.maxContentWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notifier.showReactionPicker)
                OnboardingOutlinedButton(
                  label: '我 说 了  ✨',
                  onPressed: () => sessionNotifier.skipReaction(),
                )
              else
                OnboardingOutlinedButton(
                  label: '我 说 了  ✨',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    sessionNotifier.recordSaid();
                  },
                  icon: const OnboardingAssetImage(
                    OnboardingAssets.heart,
                    width: 28,
                    height: 28,
                  ),
                ),
              if (!notifier.showReactionPicker) ...[
                const SizedBox(height: 8),
                Text(
                  '等你说完再点哦 ↗',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
