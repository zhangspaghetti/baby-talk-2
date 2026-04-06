import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final TextEditingController _caregiverController = TextEditingController(
    text: '小明妈妈',
  );
  final TextEditingController _childController = TextEditingController(
    text: '小明',
  );

  int _stepIndex = 0;
  int _childAgeMonths = 8;
  AppDifficulty _difficulty = AppDifficulty.balanced;

  @override
  void dispose() {
    _caregiverController.dispose();
    _childController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();
    final stage = RoadmapStage.forAgeMonths(_childAgeMonths);
    final steps = [
      _OnboardingStep(
        eyebrow: '小禾老师',
        title: '先把第一句说出来',
        body: 'Baby Talk 不是任务清单。它是把吃、洗、抱、玩这些真实时刻接到一句英文上。',
        child: _MentorNote(
          child: Text(
            '我会先根据宝宝月龄和你的节奏，给你一个不费劲但能马上开口的起点。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      _OnboardingStep(
        eyebrow: '先认识一下',
        title: '你希望我怎么称呼你们？',
        body: '先把称呼说自然，后面的所有提醒和日记都会像你自己的语气。',
        child: Column(
          children: [
            TextField(
              key: const Key('caregiver-name-field'),
              controller: _caregiverController,
              decoration: const InputDecoration(labelText: '家长称呼'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('child-name-field'),
              controller: _childController,
              decoration: const InputDecoration(labelText: '宝宝昵称'),
            ),
          ],
        ),
      ),
      _OnboardingStep(
        eyebrow: '匹配阶段',
        title: '宝宝现在多大了？',
        body: '年龄不是为了打标签，是为了别一下子给太难的句子。',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final months in [3, 8, 14, 22, 30])
              _ChoiceCard(
                label: '$months个月',
                detail: RoadmapStage.forAgeMonths(months).title,
                selected: _childAgeMonths == months,
                onTap: () {
                  setState(() {
                    _childAgeMonths = months;
                  });
                },
              ),
          ],
        ),
      ),
      _OnboardingStep(
        eyebrow: stage.badge,
        title: stage.title,
        body: stage.coachCopy,
        child: Column(
          children: [
            _StagePreview(stage: stage, ageLabel: '$_childAgeMonths个月'),
            const SizedBox(height: 16),
            for (final difficulty in AppDifficulty.values) ...[
              _DifficultyCard(
                difficulty: difficulty,
                selected: _difficulty == difficulty,
                onTap: () {
                  setState(() {
                    _difficulty = difficulty;
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      _OnboardingStep(
        eyebrow: '30 秒预演',
        title: '你接下来会看到什么？',
        body: '一句英文、一个动作提示、一个宝宝反应，然后花园和成长页马上有反馈。',
        child: const _MiniScenePreview(),
      ),
    ];

    final isLastStep = _stepIndex == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '对话式 Onboarding',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${_stepIndex + 1}/${steps.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_stepIndex + 1) / steps.length,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_stepIndex),
                    child: steps[_stepIndex],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_stepIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _stepIndex -= 1;
                          });
                        },
                        child: const Text('上一步'),
                      ),
                    ),
                  if (_stepIndex > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: Key(
                        isLastStep
                            ? 'onboarding-finish-button'
                            : _stepIndex == 0
                            ? 'onboarding-start-button'
                            : 'onboarding-next-button',
                      ),
                      onPressed: appState.isSyncing && isLastStep
                          ? null
                          : () async {
                              if (isLastStep) {
                                await context
                                    .read<BabyTalkAppState>()
                                    .completeOnboarding(
                                      caregiverName: _caregiverController.text,
                                      childName: _childController.text,
                                      childAgeMonths: _childAgeMonths,
                                      difficulty: _difficulty,
                                    );
                                return;
                              }

                              setState(() {
                                _stepIndex += 1;
                              });
                            },
                      child: appState.isSyncing && isLastStep
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isLastStep ? '进入首页' : '继续'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(eyebrow, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class _MentorNote extends StatelessWidget {
  const _MentorNote({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.spa_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 154,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).extension<AppThemeTone>()!.borderTone,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.selected,
    required this.onTap,
  });

  final AppDifficulty difficulty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).extension<AppThemeTone>()!.borderTone,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    difficulty.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _StagePreview extends StatelessWidget {
  const _StagePreview({required this.stage, required this.ageLabel});

  final RoadmapStage stage;
  final String ageLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ageLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(stage.label, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(stage.coachCopy, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MiniScenePreview extends StatelessWidget {
  const _MiniScenePreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Splash splash! Can you splash with me?',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).extension<AppThemeTone>()!.englishTone,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '泼水泼水！你能和我一起泼吗？',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  Chip(label: Text('安静听')),
                  Chip(label: Text('跟着发声')),
                  Chip(label: Text('没进入状态')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _MentorNote(
          child: Text('你一选反应，花园和成长页就会立刻更新。这就是 Baby Talk 的第一层闭环。'),
        ),
      ],
    );
  }
}
