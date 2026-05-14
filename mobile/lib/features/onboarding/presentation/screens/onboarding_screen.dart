import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_step_progress.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                AppStepProgress(
                  key: const Key('onboarding-step-progress'),
                  currentStep: notifier.currentStep.index,
                  totalSteps: OnboardingFlowStep.values.length,
                ),
                const SizedBox(height: 20),
                Text(l.onboardingTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l.onboardingSubtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 20),
                Container(
                  key: const Key('onboarding-local-only-banner'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.infoSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l.onboardingLocalOnly,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildConversation(theme, notifier, l),
                const SizedBox(height: 24),
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
      MentorBubble(caption: l.mentorName, message: l.onboardingMentorGreeting),
    ];

    if (notifier.currentStep.index >= OnboardingFlowStep.name.index ||
        notifier.draftName.trim().isNotEmpty) {
      widgets
        ..add(const SizedBox(height: 16))
        ..add(MentorBubble(message: l.onboardingAskName));
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
        ..add(MentorBubble(message: l.onboardingAskAge));
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
          MentorBubble(
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
        ElevatedButton(
          key: const Key('onboarding-start-button'),
          onPressed: notifier.startFlow,
          child: Text(l.onboardingStartButton),
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
              child: ElevatedButton(
                key: const Key('onboarding-name-continue'),
                onPressed: notifier.continueFromName,
                child: Text(l.onboardingContinue),
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
        GridView.builder(
          key: const Key('onboarding-age-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: OnboardingAgeBucket.values.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (context, index) {
            final bucket = OnboardingAgeBucket.values[index];
            final stageMatch = StageMatchCatalog.forAgeBucket(bucket);
            return QuickSelectCard(
              key: Key('onboarding-age-card-${bucket.wireValue}'),
              label: bucket.label,
              caption: '${stageMatch.approxMonths}月左右',
              isSelected: notifier.selectedAgeBucket == bucket,
              onTap: () {
                AppHaptics.lightTap();
                notifier.selectAgeBucket(bucket);
              },
            );
          },
        ),
        if (notifier.isContentLoading) ...[
          const SizedBox(height: 12),
          Row(
            key: const Key('onboarding-content-loading'),
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '正在准备第一颗 starter seed…',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (notifier.contentErrorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-content-error-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 10),
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
              child: ElevatedButton(
                key: const Key('onboarding-age-continue'),
                onPressed: notifier.continueFromAge,
                child: Text(l.onboardingAgeContinue),
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
          '确认后会先写入本地档案，再带你进入首页。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text('如果保存失败，我会保留刚才的输入，方便你直接重试。', style: theme.textTheme.bodySmall),
        if (starterSeed != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-preview-seed-text'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.bgSunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '准备先这样开口',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.english,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  starterSeed.phraseEnglish,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (starterSeed.phraseChinese.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
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
        ],
        if (notifier.submitErrorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('onboarding-save-error-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.errorSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              notifier.submitErrorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
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
              child: ElevatedButton(
                key: const Key('onboarding-submit-button'),
                onPressed: notifier.isSaving ? null : notifier.submit,
                child: notifier.isSaving
                    ? Row(
                        key: const Key('onboarding-submit-saving'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              '正在保存到本地',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Text(l.onboardingEnterHome),
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阶段匹配',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.accentDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stageMatch.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stageMatch.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ],
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
