import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';

class OnboardingGardenWelcomeScreen extends ConsumerWidget {
  const OnboardingGardenWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(onboardingSessionProvider).session;
    final childName = session.childName?.trim() ?? '';
    final displayName = childName.isNotEmpty ? childName : '小明';
    final colors = context.appColors;
    final theme = Theme.of(context);

    return OnboardingWarmScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            Text(
              '欢迎来到\n$displayName的花园 🌼',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colors.textPrimary,
                height: 1.46,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '我们会一起，慢慢记录每一个\n你们的温暖时刻。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                height: 1.65,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 8,
                    bottom: 28,
                    child: Opacity(
                      opacity: 0.95,
                      child: OnboardingAssetImage(
                        OnboardingAssets.wildflowers,
                        width: 118,
                        height: 150,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 30,
                    child: OnboardingAssetImage(
                      OnboardingAssets.flowerSprout,
                      width: 114,
                      height: 148,
                    ),
                  ),
                  const Positioned(
                    left: 78,
                    bottom: 18,
                    child: OnboardingAssetImage(
                      OnboardingAssets.gardenFence,
                      width: 190,
                      height: 126,
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD09A5A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF9A6A38)),
                        boxShadow: colors.warmShadowSm,
                      ),
                      child: Text(
                        '$displayName的花园',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    top: 12,
                    child: Text(
                      '✦',
                      style: TextStyle(color: colors.warning, fontSize: 14),
                    ),
                  ),
                  Positioned(
                    right: 54,
                    top: 34,
                    child: Text(
                      '✦',
                      style: TextStyle(color: colors.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            OnboardingPrimaryButton(
              label: '开始我们的花园之旅',
              onPressed: () => _completeOnboarding(context, ref),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text('去首页看看', style: TextStyle(color: colors.textPrimary)),
            ),
            const SizedBox(height: AppLayoutConstants.spacingSm),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    final session = ref.read(onboardingSessionProvider).session;
    final childName = session.childName?.trim() ?? '';
    final repository = ref.read(onboardingRepositoryProvider).requireValue;
    final snapshot = await repository.completeOnboarding(
      childDisplayName: childName.isEmpty ? '宝宝' : childName,
      ageBucket: session.ageBucket ?? OnboardingAgeBucket.zeroToSix,
    );

    if (context.mounted) {
      context.go('/', extra: snapshot);
    }
  }
}
