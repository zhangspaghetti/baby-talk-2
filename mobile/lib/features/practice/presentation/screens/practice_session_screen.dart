import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/care_path/presentation/widgets/care_turn_surface.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/l10n/app_localizations.dart';

class PracticeSessionScreen extends ConsumerWidget {
  const PracticeSessionScreen({
    super.key,
    required this.routeEntry,
    this.audioControllerFactory,
  });

  final PracticeRouteEntry routeEntry;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (!routeEntry.hasValidArgs) {
      return PracticeFallbackScaffold(
        message: _careTurnFallbackCopy(
          routeEntry.errorMessage ?? l.practiceInvalidParams,
        ),
      );
    }

    final repositoryValue = ref.watch(practiceRepositoryProvider);
    return repositoryValue.when(
      data: (_) => _PracticeSessionBody(
        routeEntry: routeEntry,
        audioControllerFactory: audioControllerFactory,
      ),
      loading: () => const _PracticeLoadingScaffold(),
      error: (error, stackTrace) => PracticeFallbackScaffold(
        message: _careTurnFallbackCopy(l.homePracticeUnavailable),
      ),
    );
  }

  String _careTurnFallbackCopy(String message) {
    return message
        .replaceAll('练习', '照护')
        .replaceAll('课程', '场景')
        .replaceAll('进度', '节奏')
        .replaceAll('完成', '收尾');
  }
}

class _PracticeLoadingScaffold extends StatelessWidget {
  const _PracticeLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(
            key: Key('practice-repository-loading'),
          ),
        ),
      ),
    );
  }
}

class _PracticeSessionBody extends ConsumerStatefulWidget {
  const _PracticeSessionBody({
    required this.routeEntry,
    required this.audioControllerFactory,
  });

  final PracticeRouteEntry routeEntry;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  ConsumerState<_PracticeSessionBody> createState() =>
      _PracticeSessionBodyState();
}

class _PracticeSessionBodyState extends ConsumerState<_PracticeSessionBody> {
  String? _requestedMomentKey;
  String? _completedMomentKey;
  String? _confirmedGeneratedContentId;
  int _startGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleStartMoment();
  }

  @override
  void didUpdateWidget(covariant _PracticeSessionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeScopeKey(oldWidget.routeEntry) !=
        _routeScopeKey(widget.routeEntry)) {
      _scheduleStartMoment();
    }
  }

  String _routeScopeKey(PracticeRouteEntry routeEntry) {
    return routeEntry.scopeLabel;
  }

  void _scheduleStartMoment() {
    final generatedContentId =
        widget.routeEntry.generatedArgs?.generatedContentId;
    final onboardingArgs = widget.routeEntry.onboardingArgs;
    final normalized = widget.routeEntry.args?.normalized();
    final scopeKey = _routeScopeKey(widget.routeEntry);
    if (_requestedMomentKey == scopeKey && _completedMomentKey == scopeKey) {
      return;
    }
    _requestedMomentKey = scopeKey;
    _completedMomentKey = null;
    final generation = ++_startGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _requestedMomentKey != scopeKey ||
          generation != _startGeneration) {
        return;
      }
      final notifier = ref.read(carePathNotifierProvider);
      final Future<void> future;
      if (onboardingArgs != null) {
        future = notifier.startContinuation(
          OnboardingCareTurnHandoff(
            completionId: onboardingArgs.completionId,
            spaceId: onboardingArgs.spaceId,
            activityId: onboardingArgs.activityId,
            entryTitle: onboardingArgs.entryTitle,
            utteranceId: onboardingArgs.utteranceId,
            english: onboardingArgs.english,
            chinese: onboardingArgs.chinese,
            source: onboardingArgs.source,
          ),
        );
      } else if (generatedContentId != null) {
        future = notifier.startGeneratedMoment(
          generatedContentId: generatedContentId,
        );
      } else if (normalized != null) {
        future = notifier.startMoment(
          spaceId: normalized.normalizedSpaceId,
          activityId: normalized.normalizedActivityId,
        );
      } else {
        return;
      }
      unawaited(
        future.whenComplete(() {
          if (!mounted ||
              _requestedMomentKey != scopeKey ||
              generation != _startGeneration) {
            return;
          }
          setState(() {
            _completedMomentKey = scopeKey;
          });
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(carePathNotifierProvider);
    final snapshot = notifier.snapshot;
    final generatedContentId =
        widget.routeEntry.generatedArgs?.generatedContentId;
    final onboardingArgs = widget.routeEntry.onboardingArgs;
    final normalizedArgs = widget.routeEntry.args?.normalized();
    final scopeKey = _routeScopeKey(widget.routeEntry);
    final bool hasMatchingSnapshot;
    if (onboardingArgs != null) {
      final hasExactSupport =
          snapshot?.currentUtterance?.phraseId == onboardingArgs.utteranceId &&
          snapshot?.currentUtterance?.sourceIdentity ==
              onboardingArgs.source.wireValue;
      final hasScopedFailure =
          notifier.phase == CareTurnPhase.error &&
          snapshot?.moment.spaceId == onboardingArgs.spaceId &&
          snapshot?.moment.activityId == onboardingArgs.activityId;
      hasMatchingSnapshot = hasExactSupport || hasScopedFailure;
    } else if (generatedContentId != null) {
      hasMatchingSnapshot =
          snapshot?.moment.generatedContentId == generatedContentId;
    } else if (normalizedArgs != null) {
      hasMatchingSnapshot =
          snapshot?.moment.spaceId == normalizedArgs.normalizedSpaceId &&
          snapshot?.moment.activityId == normalizedArgs.normalizedActivityId;
    } else {
      hasMatchingSnapshot = false;
    }

    if (!hasMatchingSnapshot ||
        _completedMomentKey != scopeKey ||
        notifier.phase == CareTurnPhase.idle ||
        notifier.phase == CareTurnPhase.loading) {
      return const _PracticeLoadingScaffold();
    }

    if (generatedContentId != null &&
        _isInteractiveGeneratedStarterReady(generatedContentId)) {
      _scheduleHandoffConfirmation(generatedContentId);
    }

    final playbackPolicy = ref
        .watch(settingsRepositoryProvider)
        .when(
          data: (_) {
            final playbackSettings = ref
                .watch(settingsNotifierProvider)
                .snapshot;
            return CareTurnAudioPlaybackPolicy(
              autoPlayEnabled: playbackSettings.autoPlayEnabled,
              playbackRate: playbackSettings.audioSpeed,
            );
          },
          loading: () => CareTurnAudioPlaybackPolicy.disabled,
          error: (_, _) => CareTurnAudioPlaybackPolicy.disabled,
        );

    return CareTurnSurface(
      notifier: notifier,
      audioControllerFactory: widget.audioControllerFactory,
      playbackPolicy: playbackPolicy,
      careAudioControllerFactory: widget.audioControllerFactory == null
          ? () => SourceNeutralCareAudioPlaybackController(
              generatedAudioRepository: ref.read(
                generatedAudioRepositoryProvider,
              ),
            )
          : null,
      onQuietExit: onboardingArgs == null
          ? () => Navigator.of(context).maybePop()
          : () => context.go(AppRouteNames.shell),
    );
  }

  void _scheduleHandoffConfirmation(String generatedContentId) {
    if (_confirmedGeneratedContentId == generatedContentId) {
      return;
    }
    _confirmedGeneratedContentId = generatedContentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _confirmedGeneratedContentId != generatedContentId ||
          !_isInteractiveGeneratedStarterReady(generatedContentId)) {
        if (_confirmedGeneratedContentId == generatedContentId) {
          _confirmedGeneratedContentId = null;
        }
        return;
      }
      // The post-frame boundary means CareTurnSurface has rendered its starter
      // and active controls. Route initiation/return are never confirmation.
      unawaited(
        ref
            .read(customSceneHandoffConfirmationCoordinatorProvider)
            .confirm(generatedContentId: generatedContentId),
      );
    });
  }

  bool _isInteractiveGeneratedStarterReady(String generatedContentId) {
    final routeContentId = widget.routeEntry.generatedArgs?.generatedContentId;
    final scopeKey = _routeScopeKey(widget.routeEntry);
    final notifier = ref.read(carePathNotifierProvider);
    return GeneratedCareTurnHandoffReadiness.isReady(
      routeContentId: routeContentId,
      completedMomentKey: _completedMomentKey,
      routeScopeKey: scopeKey,
      phase: notifier.phase,
      snapshot: notifier.snapshot,
    );
  }
}

/// Destination gate for durable custom-scene handoff confirmation. A route
/// transition alone cannot satisfy it; CareTurnSurface is confirmed next frame.
class GeneratedCareTurnHandoffReadiness {
  const GeneratedCareTurnHandoffReadiness._();

  static bool isReady({
    required String? routeContentId,
    required String? completedMomentKey,
    required String routeScopeKey,
    required CareTurnPhase phase,
    required CareTurnSnapshot? snapshot,
  }) {
    final starter = snapshot?.currentUtterance;
    return routeContentId != null &&
        routeContentId.isNotEmpty &&
        completedMomentKey == routeScopeKey &&
        phase == CareTurnPhase.utteranceReady &&
        snapshot?.moment.generatedContentId == routeContentId &&
        snapshot?.moment.contentSource == PracticeContentSource.generated &&
        starter != null &&
        !starter.isFallback &&
        snapshot?.selectedReaction == null &&
        snapshot?.nextSupportUtterance == null &&
        snapshot?.traceEventKey == null;
  }
}

class PracticeFallbackScaffold extends StatelessWidget {
  const PracticeFallbackScaffold({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(l.practiceUnavailable),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _PracticeFallback(message: message),
        ),
      ),
    );
  }
}

class _PracticeFallback extends StatelessWidget {
  const _PracticeFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('practice-safe-fallback'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.practiceBackHome),
          ),
        ],
      ),
    );
  }
}
