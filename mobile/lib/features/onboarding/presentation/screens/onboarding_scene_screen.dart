import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_design_widgets.dart';

class OnboardingSceneScreen extends ConsumerStatefulWidget {
  const OnboardingSceneScreen({super.key});

  @override
  ConsumerState<OnboardingSceneScreen> createState() =>
      _OnboardingSceneScreenState();
}

class _OnboardingSceneScreenState extends ConsumerState<OnboardingSceneScreen> {
  PracticeScene _selectedScene = PracticeScene.bath;

  static const _sceneOptions = [
    _SceneOption(
      scene: PracticeScene.bedtime,
      title: '睡前时光',
      assetName: OnboardingAssets.bedtime,
    ),
    _SceneOption(
      scene: PracticeScene.feeding,
      title: '吃饭时间',
      assetName: OnboardingAssets.feeding,
    ),
    _SceneOption(
      scene: PracticeScene.bath,
      title: '洗澡时间',
      assetName: OnboardingAssets.bath,
    ),
    _SceneOption(
      scene: PracticeScene.diaper,
      title: '换尿布',
      assetName: OnboardingAssets.diaper,
    ),
  ];

  void _selectScene(PracticeScene scene) {
    AppHaptics.lightTap();
    setState(() => _selectedScene = scene);
    // Auto-navigate to practice after scene selection
    _startPractice();
  }

  void _startPractice() {
    final notifier = ref.read(onboardingSessionProvider.notifier);
    notifier.selectScene(_selectedScene);
    context.push('/onboarding/practice');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return OnboardingWarmScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
        children: [
          Row(
            children: [
              ClipOval(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colors.bgAccentSoft),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: OnboardingAssetImage(
                      OnboardingAssets.mentor,
                      width: 62,
                      height: 62,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '小禾老师',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '你的英语育儿伙伴',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                '今晚想和宝宝\n说些什么呢？',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 31,
                  height: 1.34,
                  color: colors.textPrimary,
                ),
              ),
              const Positioned(
                right: 4,
                bottom: -22,
                child: OnboardingAssetImage(
                  OnboardingAssets.flower,
                  width: 88,
                  height: 102,
                ),
              ),
              Positioned(
                right: 0,
                top: 12,
                child: Text(
                  '✦',
                  style: TextStyle(color: colors.warning, fontSize: 15),
                ),
              ),
              Positioned(
                right: 42,
                top: 44,
                child: Text(
                  '✦',
                  style: TextStyle(color: colors.warning, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '不需要学英语，\n只需要和宝宝说几句话。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.textPrimary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.08,
            children: _sceneOptions.map((option) {
              return _WatercolorSceneCard(
                option: option,
                selected: option.scene == _selectedScene,
                onTap: () => _selectScene(option.scene),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '不知道说什么？\n点上面的场景，小禾给你几句话',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _SceneOption {
  const _SceneOption({
    required this.scene,
    required this.title,
    required this.assetName,
  });

  final PracticeScene scene;
  final String title;
  final String assetName;
}

class _WatercolorSceneCard extends StatelessWidget {
  const _WatercolorSceneCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SceneOption option;
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.accent : const Color(0xFFE9CBA8),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? colors.warmShadowSm : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: OnboardingAssetImage(option.assetName)),
            const SizedBox(height: 6),
            Text(
              option.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
