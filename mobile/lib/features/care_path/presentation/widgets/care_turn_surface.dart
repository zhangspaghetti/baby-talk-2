import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/l10n/app_localizations.dart';

typedef CareTurnTraceReady = void Function(CareTurnSnapshot snapshot);
typedef CareTurnReactionSelected =
    Future<void> Function(BabyReactionType reaction);
typedef CareTurnRetryReaction = Future<void> Function();
typedef CareTurnRetryTracePersistence = Future<void> Function();
typedef CareTurnRetryStarterPhrasePersistence = Future<void> Function();

class CareTurnSurface extends StatefulWidget {
  const CareTurnSurface({
    super.key,
    required this.notifier,
    this.audioControllerFactory,
    this.careAudioControllerFactory,
    this.playbackPolicy = CareTurnAudioPlaybackPolicy.disabled,
    this.onTraceReady,
    this.onTraceContinue,
    this.traceContinueLabel,
    this.onReactionSelected,
    this.onRetryReaction,
    this.onRetryTracePersistence,
    this.isStarterPhrasePersistenceSaving = false,
    this.onRetryStarterPhrasePersistence,
    this.onChooseAnotherMoment,
    this.flowMessage,
    this.onQuietExit,
    this.showQuietExit = true,
    this.title,
  });

  final CarePathNotifier notifier;
  final PracticeAudioController Function()? audioControllerFactory;
  final CareAudioPlaybackController Function()? careAudioControllerFactory;
  final CareTurnAudioPlaybackPolicy playbackPolicy;
  final CareTurnTraceReady? onTraceReady;
  final VoidCallback? onTraceContinue;
  final String? traceContinueLabel;
  final CareTurnReactionSelected? onReactionSelected;
  final CareTurnRetryReaction? onRetryReaction;
  final CareTurnRetryTracePersistence? onRetryTracePersistence;
  final bool isStarterPhrasePersistenceSaving;
  final CareTurnRetryStarterPhrasePersistence? onRetryStarterPhrasePersistence;
  final VoidCallback? onChooseAnotherMoment;
  final String? flowMessage;
  final VoidCallback? onQuietExit;
  final bool showQuietExit;
  final String? title;

  @override
  State<CareTurnSurface> createState() => _CareTurnSurfaceState();
}

class _CareTurnSurfaceState extends State<CareTurnSurface> {
  CareAudioPlaybackController? _audioController;
  StreamSubscription<CareAudioPlaybackCompletion>? _audioCompletionSubscription;
  bool _isPlayingAudio = false;
  bool _isAudioPaused = false;
  bool _hasPlayedAudio = false;
  String? _audioMessage;
  String? _lastNotifiedTraceEventKey;
  String? _activeAudioKey;
  String? _pendingAudioKey;
  int? _playbackIntent;
  int _audioIntent = 0;
  Future<bool>? _audioStopBarrier;
  bool _isAudioStopping = false;
  bool _audioStopFailed = false;
  String? _lastAutoPlayedAudioKey;

  @override
  void initState() {
    super.initState();
    _activeAudioKey = _audioKey(widget.notifier.snapshot?.currentUtterance);
    _initializeAudioController();
    widget.notifier.addListener(_onNotifierChanged);
    _notifyTraceIfReady();
    _scheduleAutoplayIfEligible();
  }

  @override
  void didUpdateWidget(covariant CareTurnSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final notifierChanged = !identical(oldWidget.notifier, widget.notifier);
    if (notifierChanged) {
      oldWidget.notifier.removeListener(_onNotifierChanged);
      _cancelAudioForSourceChange();
      widget.notifier.addListener(_onNotifierChanged);
      _activeAudioKey = _audioKey(widget.notifier.snapshot?.currentUtterance);
      _lastAutoPlayedAudioKey = null;
    }
    if (notifierChanged || oldWidget.onTraceReady != widget.onTraceReady) {
      _notifyTraceIfReady();
    }
    if (notifierChanged || oldWidget.playbackPolicy != widget.playbackPolicy) {
      _scheduleAutoplayIfEligible();
      _applyPlaybackRateIfActive();
    }
  }

  @override
  void dispose() {
    _audioIntent += 1;
    _pendingAudioKey = null;
    _playbackIntent = null;
    widget.notifier.removeListener(_onNotifierChanged);
    _audioCompletionSubscription?.cancel();
    unawaited(_audioController?.dispose());
    super.dispose();
  }

  void _initializeAudioController() {
    final careFactory = widget.careAudioControllerFactory;
    if (careFactory != null) {
      _audioController = careFactory();
    } else {
      final factory =
          widget.audioControllerFactory ??
          AudioplayersPracticeAudioController.new;
      _audioController = LegacyPracticeCareAudioPlaybackController(factory());
    }
    _audioCompletionSubscription = _audioController!.completionStream.listen((
      completion,
    ) {
      final playbackIntent = _playbackIntent;
      if (!mounted ||
          _isAudioStopping ||
          playbackIntent == null ||
          completion.sessionId != playbackIntent ||
          playbackIntent != _audioIntent ||
          _pendingAudioKey == null ||
          _pendingAudioKey != _activeAudioKey) {
        return;
      }
      final l = AppLocalizations.of(context)!;
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = false;
        _hasPlayedAudio = true;
        _audioMessage = l.practiceAudioPlayedOnce;
        _pendingAudioKey = null;
        _playbackIntent = null;
      });
    });
  }

  void _onNotifierChanged() {
    if (!mounted) {
      return;
    }
    final nextAudioKey = _audioKey(widget.notifier.snapshot?.currentUtterance);
    if (_activeAudioKey != nextAudioKey) {
      _cancelAudioForSourceChange();
      _lastAutoPlayedAudioKey = null;
    }
    _activeAudioKey = nextAudioKey;
    _notifyTraceIfReady();
    setState(() {});
    _scheduleAutoplayIfEligible();
  }

  void _cancelAudioForSourceChange() {
    _audioIntent += 1;
    _pendingAudioKey = null;
    _playbackIntent = null;
    _isPlayingAudio = false;
    _isAudioPaused = false;
    _audioMessage = null;
    _isAudioStopping = true;
    _audioStopFailed = false;
    final previousBarrier = _audioStopBarrier;
    late final Future<bool> barrier;
    barrier = () async {
      if (previousBarrier != null) {
        final previousStopped = await previousBarrier;
        if (!previousStopped) {
          return false;
        }
      }
      try {
        await _audioController?.stop();
        return true;
      } on Object {
        return false;
      }
    }();
    _audioStopBarrier = barrier;
    unawaited(
      barrier.then((stopped) {
        if (!mounted || !identical(_audioStopBarrier, barrier)) {
          return;
        }
        _audioStopBarrier = null;
        setState(() {
          _isAudioStopping = false;
          _audioStopFailed = !stopped;
          if (!stopped) {
            _audioMessage = AppLocalizations.of(
              context,
            )!.practiceAudioUnavailableInline;
          }
        });
      }),
    );
  }

  void _notifyTraceIfReady() {
    final callback = widget.onTraceReady;
    if (callback == null) {
      return;
    }
    final snapshot = widget.notifier.snapshot;
    final traceEventKey = snapshot?.traceEventKey?.trim();
    if (snapshot == null || traceEventKey == null || traceEventKey.isEmpty) {
      return;
    }
    if (_lastNotifiedTraceEventKey == traceEventKey) {
      return;
    }
    _lastNotifiedTraceEventKey = traceEventKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        callback(snapshot);
      }
    });
  }

  void _scheduleAutoplayIfEligible() {
    final snapshot = widget.notifier.snapshot;
    final utterance = snapshot?.currentUtterance;
    final audioKey = _audioKey(utterance);
    if (utterance == null ||
        audioKey == null ||
        _lastAutoPlayedAudioKey == audioKey ||
        snapshot?.phase != CareTurnPhase.utteranceReady ||
        !widget.playbackPolicy.autoPlayEnabled ||
        !(_audioController?.capabilities.canAutoPlay ?? false)) {
      return;
    }
    _lastAutoPlayedAudioKey = audioKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _activeAudioKey != audioKey ||
          widget.notifier.snapshot?.phase != CareTurnPhase.utteranceReady ||
          !widget.playbackPolicy.autoPlayEnabled) {
        return;
      }
      unawaited(_playCurrentUtterance(utterance));
    });
  }

  void _applyPlaybackRateIfActive() {
    final controller = _audioController;
    if (controller == null ||
        !_isPlayingAudio ||
        !controller.capabilities.canChangePlaybackRate) {
      return;
    }
    final intent = _audioIntent;
    unawaited(
      controller.setPlaybackRate(widget.playbackPolicy.playbackRate).catchError(
        (_) {
          if (mounted && intent == _audioIntent) {
            setState(() {
              _isPlayingAudio = false;
              _audioMessage = AppLocalizations.of(
                context,
              )!.practiceAudioUnavailableInline;
            });
          }
        },
      ),
    );
  }

  Future<void> _pauseCurrentAudio() async {
    final controller = _audioController;
    if (controller == null ||
        !_isPlayingAudio ||
        !controller.capabilities.canPauseAndResume) {
      return;
    }
    final intent = _audioIntent;
    final l = AppLocalizations.of(context)!;
    // Reflect the user's pause intent immediately. The generated-audio
    // controller may still be awaiting bytes, but the control must remain
    // actionable while the native pause operation drains.
    setState(() {
      _isPlayingAudio = false;
      _isAudioPaused = true;
      _audioMessage = l.practiceAudioPausedInline;
    });
    try {
      await controller.pause();
      if (!mounted || intent != _audioIntent) return;
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = true;
        _audioMessage = l.practiceAudioPausedInline;
      });
    } on Object {
      if (mounted && intent == _audioIntent) {
        setState(() {
          _isPlayingAudio = false;
          _isAudioPaused = false;
          _audioMessage = AppLocalizations.of(
            context,
          )!.practiceAudioUnavailableInline;
        });
      }
    }
  }

  Future<void> _resumeCurrentAudio() async {
    final controller = _audioController;
    if (controller == null ||
        !_isAudioPaused ||
        !controller.capabilities.canPauseAndResume) {
      return;
    }
    final intent = _audioIntent;
    final l = AppLocalizations.of(context)!;
    // Resume is also optimistic so a pause requested during generated-byte
    // loading cannot strand the user on a disabled or missing control.
    setState(() {
      _isPlayingAudio = true;
      _isAudioPaused = false;
      _audioMessage = l.practiceAudioPlayingInline;
    });
    try {
      await controller.resume();
      if (!mounted || intent != _audioIntent) return;
      setState(() {
        _isPlayingAudio = true;
        _isAudioPaused = false;
        _audioMessage = l.practiceAudioPlayingInline;
      });
    } on Object {
      if (mounted && intent == _audioIntent) {
        setState(() {
          _isAudioPaused = false;
          _audioMessage = AppLocalizations.of(
            context,
          )!.practiceAudioUnavailableInline;
        });
      }
    }
  }

  Future<void> _playCurrentUtterance(CareUtterance utterance) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppLocalizations.of(context)!;
    final controller = _audioController;
    final source = _audioSource(utterance);
    if (controller == null || source == null) {
      setState(() {
        _audioMessage = l.practiceAudioMissingInline;
      });
      messenger?.showSnackBar(
        SnackBar(content: Text(l.practiceAudioMissingSnack)),
      );
      return;
    }
    final audioKey = _audioKey(utterance);

    final intent = ++_audioIntent;
    _pendingAudioKey = audioKey;
    _playbackIntent = null;
    setState(() {
      _isPlayingAudio = true;
      _isAudioPaused = false;
      _audioMessage = l.practiceAudioLoadingInline;
    });
    try {
      final stopBarrier = _audioStopBarrier;
      if (stopBarrier != null) {
        final stopped = await stopBarrier;
        if (!stopped) {
          if (!mounted || intent != _audioIntent) {
            return;
          }
          setState(() {
            _isPlayingAudio = false;
            _audioStopFailed = true;
            _audioMessage = l.practiceAudioUnavailableInline;
          });
          return;
        }
      }
      if (!mounted ||
          intent != _audioIntent ||
          _pendingAudioKey != audioKey ||
          _activeAudioKey != audioKey) {
        return;
      }
      await controller.play(
        CareAudioPlaybackRequest(
          source: source,
          sessionId: intent,
          playbackRate: widget.playbackPolicy.playbackRate,
        ),
      );
      if (!mounted ||
          intent != _audioIntent ||
          !_isPlayingAudio ||
          _pendingAudioKey != audioKey ||
          _activeAudioKey != audioKey) {
        return;
      }
      setState(() {
        _audioMessage = l.practiceAudioPlayingInline;
        _playbackIntent = intent;
      });
    } catch (_) {
      if (!mounted || intent != _audioIntent) {
        return;
      }
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = false;
        _audioMessage = l.practiceAudioUnavailableInline;
        _pendingAudioKey = null;
        _playbackIntent = null;
      });
      messenger?.showSnackBar(
        SnackBar(content: Text(l.practiceAudioUnavailableSnack)),
      );
    }
  }

  String? _audioPlayerAsset(CareUtterance utterance) {
    final asset = utterance.audioAsset?.trim();
    if (asset == null || asset.isEmpty) {
      return null;
    }
    return asset.startsWith('assets/') ? asset.substring(7) : asset;
  }

  CareAudioSource? _audioSource(CareUtterance utterance) {
    final source = utterance.audioSource;
    if (source != null) {
      return source;
    }
    final asset = _audioPlayerAsset(utterance);
    return asset == null ? null : CareAssetAudioSource(assetPath: asset);
  }

  String? _audioKey(CareUtterance? utterance) {
    if (utterance == null) {
      return null;
    }
    final source = _audioSource(utterance);
    return '${utterance.phraseId}:${source?.hashCode}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final notifier = widget.notifier;
    final snapshot = notifier.snapshot;
    final surfaceTitle = widget.title ?? l.practiceOneTurnTitle;

    if (snapshot == null ||
        notifier.phase == CareTurnPhase.idle ||
        notifier.phase == CareTurnPhase.loading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(key: Key('care-turn-loading')),
          ),
        ),
      );
    }

    final message =
        snapshot.message ?? notifier.message ?? l.practiceContextMissing;
    if (notifier.phase == CareTurnPhase.error ||
        snapshot.currentUtterance == null) {
      return _CareTurnFallbackScaffold(
        message: widget.flowMessage?.trim().isNotEmpty == true
            ? widget.flowMessage!
            : message,
        utterance: snapshot.currentUtterance,
        selectedReaction: snapshot.selectedReaction,
        onRetryReaction: snapshot.selectedReaction == null
            ? null
            : widget.onRetryReaction,
        onChooseAnotherMoment: widget.onChooseAnotherMoment,
      );
    }

    final utterance = snapshot.currentUtterance!;
    final nextSupportUtterance = snapshot.nextSupportUtterance;
    final latestImpact = snapshot.latestGardenImpact;
    final hasConfirmedTrace =
        snapshot.traceEventKey?.trim().isNotEmpty == true &&
        (snapshot.phase == CareTurnPhase.nextSupportReady ||
            snapshot.phase == CareTurnPhase.heldWithFallback);
    final hasFailedStarterPhrasePersistence =
        widget.onRetryStarterPhrasePersistence != null;
    final blocksStarterPhraseActions =
        widget.isStarterPhrasePersistenceSaving ||
        hasFailedStarterPhrasePersistence;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: ExcludeSemantics(
          key: const Key('care-turn-appbar-title-exclude'),
          child: Text(surfaceTitle),
        ),
      ),
      body: SafeArea(
        child: Semantics(
          key: const Key('care-turn-semantics-root'),
          explicitChildNodes: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutConstants.maxContentWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppLayoutConstants.spacingLg,
                  AppLayoutConstants.spacingMd,
                  AppLayoutConstants.spacingLg,
                  AppLayoutConstants.spacingLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      key: const Key('care-turn-semantics-timing'),
                      container: true,
                      sortKey: OrdinalSortKey(3),
                      child: _CareTurnPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(
                              child: Text(
                                snapshot.moment.title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (snapshot.moment.careActionLabel
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ExcludeSemantics(
                                child: Text(
                                  snapshot.moment.careActionLabel,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              l.practiceWhenToSay,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              utterance.whenToSay,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    Semantics(
                      key: const Key('care-turn-semantics-phrase'),
                      container: true,
                      explicitChildNodes: true,
                      sortKey: OrdinalSortKey(1),
                      child: _CareTurnPanel(
                        key: const Key('care-turn-current-utterance'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              key: const Key('care-turn-semantics-english'),
                              container: true,
                              sortKey: OrdinalSortKey(1),
                              label: utterance.english,
                              child: ExcludeSemantics(
                                child: Text(
                                  utterance.english,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Semantics(
                              key: const Key('care-turn-semantics-chinese'),
                              container: true,
                              sortKey: OrdinalSortKey(2),
                              label: utterance.chinese,
                              child: ExcludeSemantics(
                                child: Text(
                                  utterance.chinese,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: colors.textPrimary),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ExcludeSemantics(
                              child: Text(
                                utterance.pronunciation,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary),
                              ),
                            ),
                            if (_audioMessage != null) ...[
                              const SizedBox(height: 12),
                              // This status is intentionally a live region, not a
                              // focus request. TalkBack keeps the reader's current
                              // position while it hears the short update.
                              Semantics(
                                key: const Key('care-turn-audio-error'),
                                container: true,
                                liveRegion: true,
                                label: _audioMessage!,
                                child: ExcludeSemantics(
                                  child: Text(
                                    _audioMessage!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: colors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    Semantics(
                      key: const Key('care-turn-semantics-actions'),
                      container: true,
                      sortKey: OrdinalSortKey(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  key: const Key(
                                    'care-turn-audio-primary-control',
                                  ),
                                  button: true,
                                  enabled:
                                      !_isPlayingAudio &&
                                      !_isAudioPaused &&
                                      !_isAudioStopping &&
                                      !_audioStopFailed,
                                  label: _hasPlayedAudio
                                      ? l.practiceReplayAudioSemantics
                                      : l.practicePlayAudioSemantics,
                                  child: OutlinedButton.icon(
                                    key: const Key('care-turn-listen-once'),
                                    onPressed:
                                        _isPlayingAudio ||
                                            _isAudioPaused ||
                                            _isAudioStopping ||
                                            _audioStopFailed
                                        ? null
                                        : () =>
                                              _playCurrentUtterance(utterance),
                                    icon: Icon(
                                      _isPlayingAudio
                                          ? Icons.equalizer_rounded
                                          : Icons.volume_up_rounded,
                                    ),
                                    label: Text(
                                      _hasPlayedAudio
                                          ? l.practiceReplayAudio
                                          : l.practiceListenOnce,
                                    ),
                                  ),
                                ),
                              ),
                              if ((_isPlayingAudio || _isAudioPaused) &&
                                  (_audioController
                                          ?.capabilities
                                          .canPauseAndResume ??
                                      false)) ...[
                                const SizedBox(
                                  width: AppLayoutConstants.spacingSm,
                                ),
                                Expanded(
                                  child: Semantics(
                                    key: const Key(
                                      'care-turn-audio-pause-control',
                                    ),
                                    button: true,
                                    label: _isAudioPaused
                                        ? l.practiceResumeAudioSemantics
                                        : l.practicePauseAudioSemantics,
                                    child: OutlinedButton.icon(
                                      key: Key(
                                        _isAudioPaused
                                            ? 'care-turn-resume-audio'
                                            : 'care-turn-pause-audio',
                                      ),
                                      onPressed: _isAudioPaused
                                          ? _resumeCurrentAudio
                                          : _pauseCurrentAudio,
                                      icon: Icon(
                                        _isAudioPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded,
                                      ),
                                      label: Text(
                                        _isAudioPaused
                                            ? l.practiceResumeAudio
                                            : l.practicePauseAudio,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(
                                width: AppLayoutConstants.spacingSm,
                              ),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('care-turn-said-button'),
                                  onPressed:
                                      snapshot.phase ==
                                              CareTurnPhase.utteranceReady &&
                                          !blocksStarterPhraseActions
                                      ? () {
                                          AppHaptics.lightTap();
                                          notifier.markSaid();
                                        }
                                      : null,
                                  icon: const Icon(Icons.check_rounded),
                                  label: Text(l.practiceSaid),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.phase == CareTurnPhase.savingTrace) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l.practiceSavingTrace,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (snapshot.phase == CareTurnPhase.reactionPrompt &&
                        !blocksStarterPhraseActions) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Semantics(
                        key: const Key('care-turn-semantics-reaction'),
                        container: true,
                        sortKey: OrdinalSortKey(5),
                        child: _CareTurnPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.practiceReactionPrompt,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SceneReactionChipRow(
                                phraseId: utterance.phraseId,
                                sceneTag: snapshot.moment.sceneTag,
                                enabled: !notifier.isBusy,
                                selectedType: snapshot.selectedReaction,
                                reactionKeyBuilder: (type) =>
                                    Key('care-reaction-${type.wireValue}'),
                                onSelected: (reactionType) async {
                                  AppHaptics.lightTap();
                                  final onReactionSelected =
                                      widget.onReactionSelected;
                                  if (onReactionSelected != null) {
                                    await onReactionSelected(reactionType);
                                    return;
                                  }
                                  await notifier.selectReaction(reactionType);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (widget.flowMessage?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Text(
                        widget.flowMessage!,
                        key: const Key('care-turn-flow-message'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (widget.isStarterPhrasePersistenceSaving) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
                        key: const Key(
                          'care-turn-starter-phrase-persistence-saving',
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '正在保存这句话…',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (hasFailedStarterPhrasePersistence) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
                        key: const Key(
                          'care-turn-starter-phrase-persistence-recovery',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '刚才这句话还没有保存好。',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const Key(
                                'care-turn-retry-starter-phrase-persistence',
                              ),
                              onPressed: widget.onRetryStarterPhrasePersistence,
                              child: const Text('重新保存并继续'),
                            ),
                            if (widget.onChooseAnotherMoment != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                key: const Key(
                                  'care-turn-choose-another-moment',
                                ),
                                onPressed: widget.onChooseAnotherMoment,
                                child: const Text('换个场景'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (nextSupportUtterance != null &&
                        snapshot.phase == CareTurnPhase.nextSupportReady) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
                        key: const Key('care-turn-next-support'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.practiceNextSupportTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              nextSupportUtterance.english,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextSupportUtterance.chinese,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              nextSupportUtterance.pronunciation,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (snapshot.phase == CareTurnPhase.heldWithFallback) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
                        key: const Key('care-turn-quiet-fallback'),
                        child: Text(
                          snapshot.message ?? l.practiceQuietFallback,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    ],
                    if (latestImpact != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
                        key: const Key('care-turn-garden-trace'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.practiceGardenTraceTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              latestImpact.headline,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              latestImpact.detail,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (hasConfirmedTrace &&
                        widget.onRetryTracePersistence != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      FilledButton(
                        key: const Key('care-turn-retry-trace-persistence'),
                        onPressed: widget.onRetryTracePersistence,
                        child: const Text('重新保存记录'),
                      ),
                    ] else if (hasConfirmedTrace &&
                        widget.onTraceContinue != null &&
                        widget.traceContinueLabel?.trim().isNotEmpty ==
                            true) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      FilledButton(
                        key: const Key('care-turn-trace-continue'),
                        onPressed: widget.onTraceContinue,
                        child: Text(widget.traceContinueLabel!),
                      ),
                    ],
                    if (widget.showQuietExit) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Semantics(
                        key: const Key('care-turn-semantics-quiet-exit'),
                        container: true,
                        sortKey: OrdinalSortKey(6),
                        child: Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            key: const Key('care-turn-quiet-exit'),
                            onPressed: widget.onQuietExit,
                            child: const Text('先这样就好'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareTurnPanel extends StatelessWidget {
  const _CareTurnPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: child,
    );
  }
}

class _CareTurnFallbackScaffold extends StatelessWidget {
  const _CareTurnFallbackScaffold({
    required this.message,
    this.utterance,
    this.selectedReaction,
    this.onRetryReaction,
    this.onChooseAnotherMoment,
  });

  final String message;
  final CareUtterance? utterance;
  final BabyReactionType? selectedReaction;
  final CareTurnRetryReaction? onRetryReaction;
  final VoidCallback? onChooseAnotherMoment;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selectedReactionLabel = selectedReaction == null
        ? null
        : sceneReactionOptions(
            null,
          ).firstWhere((option) => option.type == selectedReaction).label;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            key: const Key('care-turn-safe-fallback'),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.errorSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  label: message,
                  child: ExcludeSemantics(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (utterance != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const Key('care-turn-response-lost-context'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utterance!.english,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          utterance!.chinese,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        if (selectedReactionLabel != null) ...[
                          const SizedBox(height: 8),
                          Semantics(
                            label: '已选回应：$selectedReactionLabel',
                            child: Text(
                              '已选：$selectedReactionLabel',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (onRetryReaction != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('care-turn-retry-reaction'),
                    onPressed: onRetryReaction,
                    child: const Text('再试一次'),
                  ),
                ],
                if (onChooseAnotherMoment != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('care-turn-choose-another-moment'),
                    onPressed: onChooseAnotherMoment,
                    child: const Text('换个场景'),
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
