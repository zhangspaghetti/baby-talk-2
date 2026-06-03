// mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/l10n/app_localizations.dart';
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
    final l = AppLocalizations.of(context)!;
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
                        final notifier =
                            ref.read(onboardingSessionProvider.notifier);
                        notifier.selectScene(_resolveDefaultScene());
                        context.push('/onboarding/practice');
                      },
                      child: Text(l.onboardingV21DirectPhrase),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayoutConstants.spacingSm),

                // Mentor avatar
                Center(
                  child: Column(
                    children: [
                      _MentorAvatar(colors: colors, theme: theme, l: l),
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Text(
                        '你的英语育儿伙伴',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),

                // Title
                Text(
                  l.onboardingV21SceneTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),

                // Subtitle
                Text(
                  l.onboardingV21SceneHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),

                // 2x2 scene grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppLayoutConstants.spacingSm,
                  crossAxisSpacing: AppLayoutConstants.spacingSm,
                  childAspectRatio: 1.0,
                  children: PracticeSceneX.allScenes.map((scene) {
                    return SceneButton(
                      emoji: scene.emoji,
                      label: scene.label,
                      isSelected: _selectedScene == scene,
                      onTap: () => _onSceneTap(scene),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),

                // Helper text
                Text(
                  '不知道说什么？点下面按钮，小禾给你几句话',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppLayoutConstants.spacingMd),

                // CTA button
                FilledButton(
                  onPressed: () {
                    if (_selectedScene != null) {
                      _onSceneTap(_selectedScene!);
                    } else {
                      _onSceneTap(_resolveDefaultScene());
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    '给我几句话',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                        : l.onboardingV21AgeEntry,
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

/// Mentor avatar widget - 28×28 rounded rectangle with warm gradient.
class _MentorAvatar extends StatelessWidget {
  const _MentorAvatar({
    required this.colors,
    required this.theme,
    required this.l,
  });

  final BabyTalkColors colors;
  final ThemeData theme;
  final AppLocalizations l;

  static const LinearGradient _avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAD0B6), Color(0xFFF8E7D4)],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        gradient: _avatarGradient,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      alignment: Alignment.center,
      child: Text(
        l.onboardingMentorCaption,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.accentDark,
          fontWeight: FontWeight.w700,
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
            title: Text(AppLocalizations.of(context)!.onboardingV21AgeSkip),
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
