import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';

class OnboardingNameScreen extends HookConsumerWidget {
  const OnboardingNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final selectedAge = useState<OnboardingAgeBucket?>(null);
    final colors = context.appColors;
    final theme = Theme.of(context);

    void submit() =>
        _submit(context, ref, controller.text.trim(), selectedAge.value);

    return OnboardingWarmScaffold(
      resizeToAvoidBottomInset: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('onboarding-name-skip-top'),
              onPressed: submit,
              child: Text(
                '稍后再说',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const OnboardingMentorBubble(
            message: '小禾想帮你记录这段珍贵的成长，\n可以告诉我一些关于宝宝的\n小信息吗？',
            assetName: OnboardingAssets.mentor,
            maxWidth: 258,
          ),
          const SizedBox(height: 34),
          Text(
            '宝宝昵称（可选）',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('onboarding-name-input'),
            controller: controller,
            textInputAction: TextInputAction.done,
            maxLength: 12,
            decoration: InputDecoration(
              counterText: '',
              hintText: '比如：小宝、小明...',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: OnboardingAssetImage(
                  OnboardingAssets.wildflowers,
                  width: 28,
                  height: 28,
                ),
              ),
            ),
            onSubmitted: (_) => submit(),
          ),
          const SizedBox(height: 24),
          Text(
            '宝宝年龄',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.26,
            children: OnboardingAgeBucket.values.map((bucket) {
              return _AgeCard(
                bucket: bucket,
                selected: selectedAge.value == bucket,
                onTap: () {
                  AppHaptics.lightTap();
                  selectedAge.value = bucket;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 72),
          OnboardingPrimaryButton(
            key: const Key('onboarding-name-next'),
            label: '保存',
            onPressed: submit,
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('onboarding-name-skip-bottom'),
            onPressed: submit,
            child: Text('稍后再说', style: TextStyle(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _submit(
    BuildContext context,
    WidgetRef ref,
    String name,
    OnboardingAgeBucket? ageBucket,
  ) {
    final notifier = ref.read(onboardingSessionProvider.notifier);
    if (name.isNotEmpty) {
      notifier.setChildName(name);
    }
    if (ageBucket != null) {
      notifier.selectAgeBucket(ageBucket);
    }
    context.push('/onboarding/garden-welcome');
  }
}

class _AgeCard extends StatelessWidget {
  const _AgeCard({
    required this.bucket,
    required this.selected,
    required this.onTap,
  });

  final OnboardingAgeBucket bucket;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return AppScaleButton(
      onTap: onTap,
      scaleDown: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.accent : const Color(0xFFE9CBA8),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 5,
              child: Opacity(
                opacity: selected ? 1 : 0.45,
                child: const OnboardingAssetImage(
                  OnboardingAssets.sprout,
                  width: 28,
                  height: 24,
                ),
              ),
            ),
            Text(
              _labelFor(bucket),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(OnboardingAgeBucket bucket) {
    switch (bucket) {
      case OnboardingAgeBucket.zeroToSix:
        return '0-6 个月';
      case OnboardingAgeBucket.sixToTwelve:
        return '7-12 个月';
      case OnboardingAgeBucket.twelveToEighteen:
        return '1 岁';
      case OnboardingAgeBucket.eighteenToTwentyFour:
        return '2 岁';
      case OnboardingAgeBucket.twentyFourToThirtySix:
        return '3 岁';
    }
  }
}
