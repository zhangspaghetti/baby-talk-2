import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/care_path/presentation/widgets/care_turn_surface.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_flow_notifier.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_flow_shell.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_selection_steps.dart';
import 'package:mobile/features/onboarding/presentation/widgets/onboarding_trace_step.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingFlowScreen extends ConsumerWidget {
  const OnboardingFlowScreen({super.key, this.audioControllerFactory});

  final PracticeAudioController Function()? audioControllerFactory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(onboardingFlowNotifierProvider);
    final l = AppLocalizations.of(context)!;
    final recoveredCompletion = notifier.takeRecoveredCompletion();

    if (recoveredCompletion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRouteNames.shell, extra: recoveredCompletion);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (notifier.step == OnboardingFlowStep.careTurn) {
      return CareTurnSurface(
        notifier: ref.watch(carePathNotifierProvider),
        audioControllerFactory: audioControllerFactory,
        showQuietExit: false,
        title: l.onboardingCareTurnTitle,
        onTraceContinue: notifier.flowSnapshot.hasConfirmedTrace
            ? () => unawaited(notifier.continueFromCareTurn())
            : null,
        traceContinueLabel: l.onboardingTraceContinue,
        onReactionSelected: notifier.selectReaction,
        onRetryReaction: notifier.retryReaction,
        onRetryTracePersistence: notifier.hasPendingTracePersistence
            ? notifier.retryPersistConfirmedCareTurn
            : null,
        isStarterPhrasePersistenceSaving:
            notifier.starterPhrasePersistenceState ==
            StarterPhrasePersistenceState.saving,
        onRetryStarterPhrasePersistence:
            notifier.starterPhrasePersistenceState ==
                StarterPhrasePersistenceState.failed
            ? notifier.retryPersistStarterPhrase
            : null,
        onChooseAnotherMoment: () => unawaited(notifier.chooseAnotherMoment()),
        flowMessage: notifier.message,
        onTraceReady: (_) {},
      );
    }

    return _buildShell(context, notifier, l);
  }

  Widget _buildShell(
    BuildContext context,
    OnboardingFlowNotifier notifier,
    AppLocalizations l,
  ) {
    final message = notifier.message;
    final body = switch (notifier.step) {
      OnboardingFlowStep.welcome => _OnboardingTextStep(
        title: l.onboardingWelcomeTitle,
        body: l.onboardingWelcomeBody,
      ),
      OnboardingFlowStep.age => OnboardingAgeSelection(
        selected: notifier.flowSnapshot.ageBucket,
        enabled: !notifier.isTransitioning,
        onSelected: (value) => unawaited(notifier.selectAgeBucket(value)),
      ),
      OnboardingFlowStep.scenePreferences => OnboardingSceneSelection(
        selectedIds: notifier.flowSnapshot.selectedSceneIds,
        moments: notifier.availableMoments,
        enabled: !notifier.isTransitioning,
        onToggled: (value) => unawaited(notifier.toggleScenePreference(value)),
      ),
      OnboardingFlowStep.supportGoal => OnboardingGoalSelection(
        selected: notifier.flowSnapshot.supportGoal,
        enabled: !notifier.isTransitioning,
        onSelected: (value) => unawaited(notifier.selectSupportGoal(value)),
      ),
      OnboardingFlowStep.currentMoment => OnboardingMomentSelection(
        moments: notifier.availableMoments,
        enabled: !notifier.isTransitioning,
        onSelected: (value) => unawaited(notifier.selectCurrentMoment(value)),
      ),
      OnboardingFlowStep.trace => OnboardingTraceStep(
        gardenTraceDegraded: notifier.gardenTraceDegraded,
      ),
      OnboardingFlowStep.accountInvitation =>
        const OnboardingAccountInvitationStep(),
      OnboardingFlowStep.completing => const Center(
        child: CircularProgressIndicator(),
      ),
      OnboardingFlowStep.careTurn => const SizedBox.shrink(),
    };

    return OnboardingFlowShell(
      progress: _progressFor(notifier.step),
      isBusy: notifier.isBusy,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          body,
          if (message != null && message.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(message, key: const Key('onboarding-flow-message')),
          ],
        ],
      ),
      primaryLabel: _primaryLabel(notifier.step, l),
      onPrimaryPressed: () => _onPrimaryPressed(context, notifier),
      secondaryLabel: notifier.step == OnboardingFlowStep.accountInvitation
          ? l.onboardingContinueLocal
          : null,
      onSecondaryPressed: notifier.step == OnboardingFlowStep.accountInvitation
          ? () => _completeLocally(context, notifier)
          : null,
    );
  }

  String? _primaryLabel(OnboardingFlowStep step, AppLocalizations l) =>
      switch (step) {
        OnboardingFlowStep.welcome => l.onboardingStart,
        OnboardingFlowStep.age ||
        OnboardingFlowStep.scenePreferences ||
        OnboardingFlowStep.supportGoal => l.onboardingTraceContinue,
        OnboardingFlowStep.trace => l.onboardingTraceContinue,
        OnboardingFlowStep.accountInvitation => l.onboardingSaveAccount,
        OnboardingFlowStep.currentMoment ||
        OnboardingFlowStep.careTurn ||
        OnboardingFlowStep.completing => null,
      };

  void _onPrimaryPressed(
    BuildContext context,
    OnboardingFlowNotifier notifier,
  ) {
    switch (notifier.step) {
      case OnboardingFlowStep.welcome:
        unawaited(notifier.continueFromWelcome());
      case OnboardingFlowStep.age:
        unawaited(notifier.continueFromAge());
      case OnboardingFlowStep.scenePreferences:
        unawaited(notifier.continueFromScenePreferences());
      case OnboardingFlowStep.supportGoal:
        unawaited(notifier.continueFromSupportGoal());
      case OnboardingFlowStep.trace:
        unawaited(notifier.continueFromTrace());
      case OnboardingFlowStep.accountInvitation:
        unawaited(_saveToAccount(context, notifier));
      case OnboardingFlowStep.currentMoment ||
          OnboardingFlowStep.careTurn ||
          OnboardingFlowStep.completing:
        return;
    }
  }

  Future<void> _saveToAccount(
    BuildContext context,
    OnboardingFlowNotifier notifier,
  ) async {
    final alreadyCompleted = await notifier.beginAccountSave();
    if (!context.mounted) {
      return;
    }
    if (alreadyCompleted != null && notifier.takeShellNavigation()) {
      context.go(AppRouteNames.shell, extra: alreadyCompleted);
      return;
    }
    if (!notifier.takeAccountEntryNavigation()) {
      return;
    }
    final result = await context.push<Object?>(
      AppRouteNames.account,
      extra: AccountEntryOrigin.onboardingContinuation,
    );
    if (!context.mounted) {
      return;
    }
    final completed = await notifier.handleAccountReturn(result);
    if (completed != null &&
        notifier.takeShellNavigation() &&
        context.mounted) {
      context.go(AppRouteNames.shell, extra: completed);
    }
  }

  Future<void> _completeLocally(
    BuildContext context,
    OnboardingFlowNotifier notifier,
  ) async {
    final completed = await notifier.chooseLocalOnly();
    if (completed != null &&
        notifier.takeShellNavigation() &&
        context.mounted) {
      context.go(AppRouteNames.shell, extra: completed);
    }
  }
}

class _OnboardingTextStep extends StatelessWidget {
  const _OnboardingTextStep({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

double _progressFor(OnboardingFlowStep step) => switch (step) {
  OnboardingFlowStep.welcome => 0.08,
  OnboardingFlowStep.age => 0.2,
  OnboardingFlowStep.scenePreferences => 0.36,
  OnboardingFlowStep.supportGoal => 0.52,
  OnboardingFlowStep.currentMoment => 0.68,
  OnboardingFlowStep.careTurn => 0.76,
  OnboardingFlowStep.trace => 0.86,
  OnboardingFlowStep.accountInvitation || OnboardingFlowStep.completing => 1,
};
