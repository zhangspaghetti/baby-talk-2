// mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/app/widgets/app_seed_sprout.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingCompleteScreen extends ConsumerStatefulWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  ConsumerState<OnboardingCompleteScreen> createState() =>
      _OnboardingCompleteScreenState();
}

class _OnboardingCompleteScreenState
    extends ConsumerState<OnboardingCompleteScreen> {
  bool _textVisible = false;

  void _onSproutComplete() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _textVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(onboardingSessionProvider);
    final session = notifier.session;
    final scene = session.selectedScene;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.screenPadding,
              children: [
                // Top bar
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        '小禾老师 / 今天已完成',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                // Mentor bubble
                AppMentorBubble(message: session.completionBubbleCopy),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                // Sprout animation
                Center(
                  child: AppSeedSprout(
                    size: 120,
                    onAnimationComplete: _onSproutComplete,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                // Dynamic title (fades in after sprout)
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (scene != null)
                        Text(
                          scene.completionTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        '下次打开，小禾会给你新的一句。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      if (session.completionReactionSummary != null) ...[
                        const SizedBox(height: AppLayoutConstants.spacingSm),
                        Text(
                          session.completionReactionSummary!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacing2xl),
                // Buttons
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      AppScaleButton(
                        scaleDown: 0.97,
                        onTap: () {
                          context.go('/onboarding/practice');
                        },
                        child: const ElevatedButton(
                          onPressed: null,
                          child: Text('再来一句'),
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      TextButton(
                        onPressed: () => _completeOnboarding(context, ref),
                        child: const Text('先到这里'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final session = ref.read(onboardingSessionProvider).session;
    final ageBucket = session.ageBucket ?? OnboardingAgeBucket.zeroToSix;

    final repository = ref.read(onboardingRepositoryProvider).requireValue;
    await repository.completeOnboarding(
      childDisplayName: session.childName.isEmpty ? '宝宝' : session.childName,
      ageBucket: ageBucket,
    );

    if (context.mounted) {
      context.go('/');
    }
  }
}
