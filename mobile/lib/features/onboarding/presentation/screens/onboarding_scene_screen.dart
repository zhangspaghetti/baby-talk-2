// mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/onboarding/presentation/widgets/scene_button.dart';

class OnboardingSceneScreen extends ConsumerStatefulWidget {
  const OnboardingSceneScreen({super.key});

  @override
  ConsumerState<OnboardingSceneScreen> createState() =>
      _OnboardingSceneScreenState();
}

class _OnboardingSceneScreenState extends ConsumerState<OnboardingSceneScreen> {
  PracticeScene? _selectedScene;
  OnboardingAgeBucket? _selectedAge;
  bool _showAgePanel = false;

  @override
  void initState() {
    super.initState();
    _selectedScene = _resolveDefaultScene();
  }

  PracticeScene _resolveDefaultScene() {
    final session = ref.read(onboardingSessionProvider).session;
    if (session.selectedScene != null) return session.selectedScene!;
    return PracticeSceneX.defaultSceneForHour(DateTime.now().hour);
  }

  void _onSceneTap(PracticeScene scene) {
    setState(() => _selectedScene = scene);
    final notifier = ref.read(onboardingSessionProvider.notifier);
    notifier.selectScene(scene);
    context.push('/onboarding/practice');
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final notifier = ref
                            .read(onboardingSessionProvider.notifier);
                        notifier.selectScene(_resolveDefaultScene());
                        context.push('/onboarding/practice');
                      },
                      child: const Text('直接给一句'),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                const AppMentorBubble(
                  message: '选个正在发生的场景，小禾给你一句现在就能说的。',
                  caption: '小禾老师',
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                Text(
                  '今天先说一句',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(
                  '选个正在发生的场景',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                ...PracticeSceneX.allScenes.map((scene) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppLayoutConstants.spacingSm,
                    ),
                    child: SceneButton(
                      label: scene.label,
                      isSelected: _selectedScene == scene,
                      onTap: () => _onSceneTap(scene),
                    ),
                  );
                }),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                // Age entry (dashed outline button)
                OutlinedButton.icon(
                  key: const Key('onboarding-age-entry'),
                  onPressed: () {
                    setState(() => _showAgePanel = !_showAgePanel);
                  },
                  icon: const Icon(Icons.child_care_outlined),
                  label: Text(
                    _selectedAge != null
                        ? '${_selectedAge!.label} ✓'
                        : '宝宝多大？可稍后补',
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.outlineSoft,
                      style: BorderStyle.solid,
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                if (_showAgePanel) ...[
                  const SizedBox(height: AppLayoutConstants.spacingSm),
                  _AgeSelectionPanel(
                    selected: _selectedAge,
                    onSelected: (bucket) {
                      setState(() {
                        _selectedAge = bucket;
                        _showAgePanel = false;
                      });
                      ref
                          .read(onboardingSessionProvider.notifier)
                          .selectAgeBucket(bucket);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeSelectionPanel extends StatelessWidget {
  const _AgeSelectionPanel({
    required this.selected,
    required this.onSelected,
  });

  final OnboardingAgeBucket? selected;
  final ValueChanged<OnboardingAgeBucket> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: AppLayoutConstants.bannerPadding,
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...OnboardingAgeBucket.values.map((bucket) {
            return ListTile(
              title: Text(bucket.label),
              selected: selected == bucket,
              onTap: () => onSelected(bucket),
              contentPadding: EdgeInsets.zero,
            );
          }),
          ListTile(
            title: const Text('先跳过'),
            onTap: () {
              // Close panel without selecting
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
