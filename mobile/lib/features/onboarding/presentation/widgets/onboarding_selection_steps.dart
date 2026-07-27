import 'package:flutter/material.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingAgeSelection extends StatelessWidget {
  const OnboardingAgeSelection({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final OnboardingAgeBucket? selected;
  final ValueChanged<OnboardingAgeBucket> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _SelectionColumn(
      title: l.onboardingAgeSelectionTitle,
      children: OnboardingAgeBucket.values
          .map(
            (value) => _SelectionCard(
              buttonKey: Key('onboarding-age-${_ageKeySuffix(value)}'),
              label: value.label,
              selected: selected == value,
              onPressed: enabled ? () => onSelected(value) : null,
            ),
          )
          .toList(growable: false),
    );
  }
}

class OnboardingSceneSelection extends StatelessWidget {
  const OnboardingSceneSelection({
    super.key,
    required this.selectedIds,
    required this.moments,
    required this.onToggled,
    this.enabled = true,
  });

  final List<String> selectedIds;
  final List<OnboardingMomentChoice> moments;
  final ValueChanged<String> onToggled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _SelectionColumn(
      title: l.onboardingScenesTitle,
      body: l.onboardingScenesBody,
      children: moments
          .map(
            (moment) => _SelectionCard(
              buttonKey: Key('onboarding-scene-${moment.activityId}'),
              label: moment.title,
              detail: moment.summary,
              selected: selectedIds.contains(moment.activityId),
              onPressed: enabled ? () => onToggled(moment.activityId) : null,
            ),
          )
          .toList(growable: false),
    );
  }
}

class OnboardingGoalSelection extends StatelessWidget {
  const OnboardingGoalSelection({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final OnboardingSupportGoal? selected;
  final ValueChanged<OnboardingSupportGoal> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = <(OnboardingSupportGoal, String, String)>[
      (
        OnboardingSupportGoal.firstWords,
        'first-words',
        l.onboardingGoalFirstWords,
      ),
      (
        OnboardingSupportGoal.moreNatural,
        'more-natural',
        l.onboardingGoalNatural,
      ),
      (OnboardingSupportGoal.dailyHabit, 'daily-habit', l.onboardingGoalHabit),
    ];
    return _SelectionColumn(
      title: l.onboardingGoalTitle,
      children: options
          .map(
            (option) => _SelectionCard(
              buttonKey: Key('onboarding-goal-${option.$2}'),
              label: option.$3,
              selected: selected == option.$1,
              onPressed: enabled ? () => onSelected(option.$1) : null,
            ),
          )
          .toList(growable: false),
    );
  }
}

class OnboardingMomentSelection extends StatelessWidget {
  const OnboardingMomentSelection({
    super.key,
    required this.moments,
    required this.onSelected,
    this.enabled = true,
  });

  final List<OnboardingMomentChoice> moments;
  final ValueChanged<OnboardingMomentChoice> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _SelectionColumn(
      title: l.onboardingMomentTitle,
      children: moments
          .map(
            (moment) => _SelectionCard(
              buttonKey: Key(
                'onboarding-moment-${moment.spaceId}-${moment.activityId}',
              ),
              label: moment.title,
              detail: moment.summary,
              selected: false,
              onPressed: enabled ? () => onSelected(moment) : null,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SelectionColumn extends StatelessWidget {
  const _SelectionColumn({
    required this.title,
    required this.children,
    this.body,
  });

  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (body != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(body!, style: Theme.of(context).textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.detail,
  });

  final Key buttonKey;
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: OutlinedButton(
          key: buttonKey,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            padding: const EdgeInsets.all(16),
          ),
          onPressed: onPressed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label),
              if (detail != null && detail!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(detail!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _ageKeySuffix(OnboardingAgeBucket value) => switch (value) {
  OnboardingAgeBucket.zeroToSix => '0-6',
  OnboardingAgeBucket.sevenToTwelve => '7-12',
  OnboardingAgeBucket.oneToTwo => '1-2',
  OnboardingAgeBucket.twoToThree => '2-3',
};
