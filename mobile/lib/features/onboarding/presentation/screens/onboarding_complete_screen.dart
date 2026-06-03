// mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_seed_sprout.dart';
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
                // Sprout animation
                Center(
                  child: AppSeedSprout(
                    size: 160,
                    onAnimationComplete: _onSproutComplete,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                // Title (fades in after sprout)
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '你刚刚和宝宝分享了第一组英语 🌱',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        '一颗小种子已经种下，持续的表达会让它慢慢成长。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacing2xl),
                // CTA button
                AnimatedOpacity(
                  opacity: _textVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          context.go('/onboarding/practice');
                        },
                        child: const Text('看看我的花园'),
                      ),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      TextButton(
                        onPressed: () => _completeOnboarding(context, ref),
                        child: const Text('稍后再说'),
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
    final snapshot = await repository.completeOnboarding(
      childDisplayName:
          (session.childName == null || session.childName!.isEmpty)
              ? '宝宝'
              : session.childName!,
      ageBucket: ageBucket,
    );

    if (context.mounted) {
      context.go('/', extra: snapshot);
    }
  }
}
