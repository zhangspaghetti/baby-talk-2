import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_scale_button.dart';
import 'package:mobile/app/widgets/app_step_progress.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_notifier.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mini_seed_card.dart';
import 'package:mobile/features/onboarding/presentation/widgets/quick_select_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final nameFocusNode = useFocusNode();
    final updatingNameFromNotifier = useState<bool>(false);
    final lastHandledStep = useState<OnboardingFlowStep?>(null);
    final navigationScheduled = useState<bool>(false);

    // Register listener on mount, clean up on dispose.
    useEffect(() {
      void listener() {
        if (updatingNameFromNotifier.value) return;
        ref
            .read(onboardingNotifierProvider.notifier)
            .updateDraftName(nameController.text);
      }

      nameController.addListener(listener);
      return () => nameController.removeListener(listener);
    }, const []);

    // Sync controller text with notifier on every rebuild (replaces didChangeDependencies).
    final notifier = ref.watch(onboardingNotifierProvider);
    if (nameController.text != notifier.draftName) {
      updatingNameFromNotifier.value = true;
      nameController.value = TextEditingValue(
        text: notifier.draftName,
        selection: TextSelection.collapsed(offset: notifier.draftName.length),
      );
      updatingNameFromNotifier.value = false;
    }

    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);

    // Sync focus for current step.
    if (lastHandledStep.value != notifier.currentStep) {
      lastHandledStep.value = notifier.currentStep;
      if (notifier.currentStep == OnboardingFlowStep.name) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          nameFocusNode.requestFocus();
        });
      } else if (nameFocusNode.hasFocus) {
        nameFocusNode.unfocus();
      }
    }

    // Navigate to shell when onboarding completes.
    if (!navigationScheduled.value &&
        notifier.navigationRequestToken > 0 &&
        notifier.completedSnapshot != null) {
      navigationScheduled.value = true;
      final snapshot = notifier.completedSnapshot!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/', extra: snapshot);
      });
    }

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
                AppStepProgress(
                  key: const Key('onboarding-step-progress'),
                  currentStep: notifier.currentStep.index,
                  totalSteps: OnboardingFlowStep.values.length,
                ),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                Text(l.onboardingTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(l.onboardingSubtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppLayoutConstants.spacingLg),
                Container(
                  key: const Key('onboarding-local-only-banner'),
                  padding: AppLayoutConstants.bannerPadding,
                  decoration: BoxDecoration(
                    color: colors.infoSoft,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.cardRadius,
                    ),
                  ),
                  child: Text(
                    l.onboardingLocalOnly,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                ..._buildConversation(theme, notifier, l),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineSoft),
                    boxShadow: colors.warmShadowSm,
                  ),
                  child: _StepComposer(
                    nameController: nameController,
                    nameFocusNode: nameFocusNode,
                    notifier: notifier,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConversation(
    ThemeData theme,
    OnboardingNotifier notifier,
    AppLocalizations l,
  ) {
    final widgets = <Widget>[
      AppMentorBubble(caption: l.mentorName, message: l.onboardingMentorGreeting),
    ];

    if (notifier.currentStep.index >= OnboardingFlowStep.name.index ||
        notifier.draftName.trim().isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(AppMentorBubble(message: l.onboardingAskName));
    }

    if (notifier.draftName.trim().isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 12))
        ..add(_UserBubble(message: notifier.draftName.trim()));
    }

    if (notifier.currentStep.index >= OnboardingFlowStep.age.index ||
        notifier.selectedAgeBucket != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(AppMentorBubble(message: l.onboardingAskAge));
    }

    final selectedAgeBucket = notifier.selectedAgeBucket;
    final stageMatch = notifier.stageMatch;
    if (selectedAgeBucket != null && stageMatch != null) {
      widgets
        ..add(const SizedBox(height: 12))
        ..add(
          _UserBubble(
            message: '${selectedAgeBucket.label} · ${stageMatch.title}',
          ),
        );
    }

    if (notifier.currentStep == OnboardingFlowStep.preview &&
        selectedAgeBucket != null &&
        stageMatch != null) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(
          AppMentorBubble(
            message: l.onboardingStagePreview(notifier.draftName.trim()),
          ),
        )
        ..add(const SizedBox(height: 16))
        ..add(
          _StageMatchCard(
            key: const Key('onboarding-stage-match-card'),
            stageMatch: stageMatch,
          ),
        );

      final starterSeed = notifier.starterSeed;
      if (starterSeed != null) {
        widgets
          ..add(const SizedBox(height: 16))
          ..add(
            MiniSeedCard(
              english: starterSeed.phraseEnglish,
              chinese: starterSeed.phraseChinese,
            ),
          );
      }
    }

    return widgets;
  }
}

class _StepComposer extends StatelessWidget {
  const _StepComposer({
    required this.nameController,
    required this.nameFocusNode,
    required this.notifier,
  });

  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    switch (notifier.currentStep) {
      case OnboardingFlowStep.welcome:
        return _WelcomeStep(notifier: notifier);
      case OnboardingFlowStep.name:
        return _NameStep(
          notifier: notifier,
          nameController: nameController,
          nameFocusNode: nameFocusNode,
        );
      case OnboardingFlowStep.age:
        return _AgeStep(notifier: notifier);
      case OnboardingFlowStep.preview:
        return _PreviewStep(notifier: notifier);
    }
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.notifier});

  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.onboardingWelcomeInfo,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.onboardingWelcomeDetail,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        AppScaleButton(
          scaleDown: 0.97,
          onTap: () {
            AppHaptics.lightTap();
            notifier.startFlow();
          },
          child: ElevatedButton(
            key: const Key('onboarding-start-button'),
            onPressed: null, // handled by AppScaleButton
            child: Text(l.onboardingStartButton),
          ),
        ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.notifier,
    required this.nameController,
    required this.nameFocusNode,
  });

  final OnboardingNotifier notifier;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('onboarding-name-input'),
          controller: nameController,
          focusNode: nameFocusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => notifier.continueFromName(),
          decoration: InputDecoration(
            labelText: l.onboardingNameLabel,
            hintText: l.onboardingNameHint,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.onboardingNameHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (notifier.nameErrorMessage != null) ...[
          const SizedBox(height: 12),
          AppBanner(
            key: const Key('onboarding-name-error'),
            message: notifier.nameErrorMessage!,
            backgroundColor: colors.errorSoft,
            foregroundColor: colors.error,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: notifier.goBack,
                child: Text(l.onboardingBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppScaleButton(
                scaleDown: 0.97,
                onTap: () {
                  AppHaptics.mediumTap();
                  notifier.continueFromName();
                },
                child: ElevatedButton(
                  key: const Key('onboarding-name-continue'),
                  onPressed: null, // handled by AppScaleButton
                  child: Text(l.onboardingContinue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgeStep extends StatelessWidget {
  const _AgeStep({required this.notifier});

  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.onboardingAgeTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(l.onboardingAgeHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final useTwoColumns =
                constraints.maxWidth < 360 || textScale >= 1.2;
            return GridView.builder(
              key: const Key('onboarding-age-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: OnboardingAgeBucket.values.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: useTwoColumns ? 2 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: useTwoColumns ? 1.65 : 0.76,
              ),
              itemBuilder: (context, index) {
                final bucket = OnboardingAgeBucket.values[index];
                final stageMatch = StageMatchCatalog.forAgeBucket(bucket);
                return QuickSelectCard(
                  key: Key('onboarding-age-card-${bucket.wireValue}'),
                  label: bucket.label,
                  caption: l.onboardingAgeMonths(stageMatch.approxMonths),
                  isSelected: notifier.selectedAgeBucket == bucket,
                  onTap: () {
                    AppHaptics.lightTap();
                    notifier.selectAgeBucket(bucket);
                  },
                );
              },
            );
          },
        ),
        if (notifier.isContentLoading) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Row(
            key: const Key('onboarding-content-loading'),
            children: [
              const SizedBox(
                width: AppLayoutConstants.iconSizeSm,
                height: AppLayoutConstants.iconSizeSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppLayoutConstants.spacingXs),
              Expanded(
                child: Text(
                  l.onboardingContentLoading,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (notifier.contentErrorMessage != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Container(
            key: const Key('onboarding-content-error-banner'),
            width: double.infinity,
            padding: AppLayoutConstants.bannerPadding,
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.cardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notifier.contentErrorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                OutlinedButton(
                  key: const Key('onboarding-content-retry'),
                  onPressed: notifier.retryContentLoad,
                  child: Text(l.onboardingContentRetry),
                ),
              ],
            ),
          ),
        ],
        if (notifier.ageErrorMessage != null) ...[
          const SizedBox(height: 12),
          AppBanner(
            key: const Key('onboarding-age-error'),
            message: notifier.ageErrorMessage!,
            backgroundColor: colors.errorSoft,
            foregroundColor: colors.error,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: notifier.goBack,
                child: Text(l.onboardingBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppScaleButton(
                scaleDown: 0.97,
                onTap: () {
                  AppHaptics.mediumTap();
                  notifier.continueFromAge();
                },
                child: ElevatedButton(
                  key: const Key('onboarding-age-continue'),
                  onPressed: null, // handled by AppScaleButton
                  child: Text(l.onboardingAgeContinue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({required this.notifier});

  final OnboardingNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final starterSeed = notifier.starterSeed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.onboardingPreviewConfirm,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        Text(l.onboardingPreviewRetryHint, style: theme.textTheme.bodySmall),
        if (starterSeed != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Container(
            key: const Key('onboarding-preview-seed-text'),
            width: double.infinity,
            padding: AppLayoutConstants.bannerPadding,
            decoration: BoxDecoration(
              color: colors.bgSunken,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.cardRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.onboardingPreviewSeedLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.english,
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(
                  starterSeed.phraseEnglish,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (starterSeed.phraseChinese.trim().isNotEmpty) ...[
                  const SizedBox(height: AppLayoutConstants.spacingXs),
                  Text(
                    starterSeed.phraseChinese,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            l.onboardingMiniSceneActionHint,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stackActions =
                  constraints.maxWidth < 360 || textScale >= 1.25;
              final playButton = _buildPlayButton(context, l, notifier);
              final saidButton = _buildSaidButton(context, l, notifier);

              if (stackActions) {
                return Column(
                  key: const Key('onboarding-first-phrase-actions-stacked'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    playButton,
                    const SizedBox(height: AppLayoutConstants.spacingSm),
                    saidButton,
                  ],
                );
              }

              return Row(
                key: const Key('onboarding-first-phrase-actions-row'),
                children: [
                  Expanded(child: playButton),
                  const SizedBox(width: AppLayoutConstants.spacingSm),
                  Expanded(child: saidButton),
                ],
              );
            },
          ),
          if (notifier.hasRecordedFirstPhraseAction) ...[
            const SizedBox(height: AppLayoutConstants.spacingSm),
            AppBanner(
              key: const Key('onboarding-first-seed-recorded'),
              message: l.onboardingMiniSceneRecorded,
              backgroundColor: colors.successSoft,
              foregroundColor: colors.success,
              icon: Icons.eco_outlined,
            ),
          ],
          if (notifier.firstPhraseActionErrorMessage != null) ...[
            const SizedBox(height: AppLayoutConstants.spacingSm),
            Semantics(
              container: true,
              liveRegion: true,
              label: l.onboardingFirstPhraseActionErrorSemantics(
                notifier.firstPhraseActionErrorMessage!,
              ),
              child: ExcludeSemantics(
                child: AppBanner(
                  key: const Key('onboarding-first-phrase-error-banner'),
                  message: notifier.firstPhraseActionErrorMessage!,
                  backgroundColor: colors.errorSoft,
                  foregroundColor: colors.error,
                ),
              ),
            ),
          ],
        ],
        if (notifier.submitErrorMessage != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Semantics(
            container: true,
            liveRegion: true,
            label: l.onboardingSaveErrorSemantics(notifier.submitErrorMessage!),
            child: ExcludeSemantics(
              child: Container(
                key: const Key('onboarding-save-error-banner'),
                width: double.infinity,
                padding: AppLayoutConstants.bannerPadding,
                decoration: BoxDecoration(
                  color: colors.errorSoft,
                  borderRadius: BorderRadius.circular(
                    AppLayoutConstants.cardRadius,
                  ),
                ),
                child: Text(
                  notifier.submitErrorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppLayoutConstants.spacingMd),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-back-button'),
                onPressed: notifier.isSaving ? null : notifier.goBack,
                child: Text(l.onboardingPreviewBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppScaleButton(
                scaleDown: 0.97,
                onTap: notifier.canSubmit
                    ? () {
                        AppHaptics.mediumTap();
                        notifier.submit();
                      }
                    : null,
                child: ElevatedButton(
                  key: const Key('onboarding-submit-button'),
                  onPressed: null, // handled by AppScaleButton
                  child: notifier.isSaving
                      ? Row(
                          key: const Key('onboarding-submit-saving'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: AppLayoutConstants.iconSizeMd,
                              height: AppLayoutConstants.iconSizeMd,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: AppLayoutConstants.spacingXs),
                            Flexible(
                              child: Text(
                                l.onboardingSaving,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          notifier.hasRecordedFirstPhraseAction
                              ? l.onboardingEnterHome
                              : l.onboardingSayFirstBeforeHome,
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayButton(
    BuildContext context,
    AppLocalizations l,
    OnboardingNotifier notifier,
  ) {
    final colors = context.appColors;
    return AppScaleButton(
      scaleDown: 0.95,
      onTap:
          notifier.isRecordingFirstPhraseAction || notifier.isPlayingFirstPhrase
          ? null
          : () {
              AppHaptics.lightTap();
              unawaited(notifier.playFirstPhrase());
            },
      child: Container(
        key: const Key('onboarding-first-phrase-play'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineSoft),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            notifier.isPlayingFirstPhrase
                ? const SizedBox(
                    width: AppLayoutConstants.iconSizeSm,
                    height: AppLayoutConstants.iconSizeSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.volume_up_outlined,
                    size: 18,
                    color: colors.textSecondary,
                  ),
            const SizedBox(width: 6),
            Text(
              notifier.isPlayingFirstPhrase
                  ? l.onboardingMiniScenePlaying
                  : l.onboardingMiniScenePlay,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaidButton(
    BuildContext context,
    AppLocalizations l,
    OnboardingNotifier notifier,
  ) {
    return AppScaleButton(
      scaleDown: 0.97,
      onTap:
          notifier.isRecordingFirstPhraseAction ||
              notifier.hasRecordedFirstPhraseAction
          ? null
          : () {
              AppHaptics.mediumTap();
              notifier.markFirstPhraseSaid();
            },
      child: ElevatedButton.icon(
        key: const Key('onboarding-first-phrase-said'),
        onPressed: null, // handled by AppScaleButton
        icon: notifier.isRecordingFirstPhraseAction
            ? const SizedBox(
                width: AppLayoutConstants.iconSizeSm,
                height: AppLayoutConstants.iconSizeSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(
          notifier.isRecordingFirstPhraseAction
              ? l.onboardingMiniSceneRecording
              : l.onboardingMiniSceneSaid,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _StageMatchCard extends StatelessWidget {
  const _StageMatchCard({super.key, required this.stageMatch});

  final StageMatch stageMatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l.onboardingStageMatchSemantics(
        stageMatch.title,
        stageMatch.summary,
      ),
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: AppLayoutConstants.bannerPadding,
          decoration: BoxDecoration(
            color: colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.onboardingStageMatch,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.accentDark,
                ),
              ),
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Text(
                stageMatch.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Text(
                stageMatch.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            boxShadow: colors.warmShadowSm,
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  }
}
