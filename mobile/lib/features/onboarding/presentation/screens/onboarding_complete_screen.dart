import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';

class OnboardingCompleteScreen extends StatelessWidget {
  const OnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return OnboardingWarmScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 54, 24, 24),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    runAlignment: WrapAlignment.spaceEvenly,
                    children: List.generate(
                      14,
                      (index) => Text(
                        '✦',
                        style: TextStyle(
                          color: colors.warning.withValues(alpha: 0.6),
                          fontSize: index.isEven ? 15 : 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: OnboardingAssetImage(
                    OnboardingAssets.sprout,
                    width: 210,
                    height: 178,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Text(
              '你刚刚和宝宝\n分享了第一组英语 🌱',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '一颗小种子已经种下，\n持续的表达会让它慢慢成长。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                height: 1.7,
              ),
            ),
            const Spacer(flex: 3),
            OnboardingPrimaryButton(
              label: '看看我的花园',
              onPressed: () => context.push('/onboarding/garden-welcome'),
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
}
