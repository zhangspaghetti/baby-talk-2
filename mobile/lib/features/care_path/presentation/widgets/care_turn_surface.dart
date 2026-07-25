import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
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
    this.onTraceReady,
    this.onTraceContinue,
    this.traceContinueLabel,
    this.onReactionSelected,
    this.onRetryReaction,
    this.onRetryTracePersistence,
    this.onRetryStarterPhrasePersistence,
    this.onChooseAnotherMoment,
    this.flowMessage,
    this.onQuietExit,
    this.showQuietExit = true,
    this.title,
  });

  final CarePathNotifier notifier;
  final PracticeAudioController Function()? audioControllerFactory;
  final CareTurnTraceReady? onTraceReady;
  final VoidCallback? onTraceContinue;
  final String? traceContinueLabel;
  final CareTurnReactionSelected? onReactionSelected;
  final CareTurnRetryReaction? onRetryReaction;
  final CareTurnRetryTracePersistence? onRetryTracePersistence;
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
  PracticeAudioController? _audioController;
  StreamSubscription<void>? _audioCompletionSubscription;
  bool _isPlayingAudio = false;
  String? _audioMessage;
  String? _lastNotifiedTraceEventKey;

  @override
  void initState() {
    super.initState();
    _initializeAudioController();
    widget.notifier.addListener(_onNotifierChanged);
    _notifyTraceIfReady();
  }

  @override
  void didUpdateWidget(covariant CareTurnSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final notifierChanged = !identical(oldWidget.notifier, widget.notifier);
    if (notifierChanged) {
      oldWidget.notifier.removeListener(_onNotifierChanged);
      widget.notifier.addListener(_onNotifierChanged);
    }
    if (notifierChanged || oldWidget.onTraceReady != widget.onTraceReady) {
      _notifyTraceIfReady();
    }
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onNotifierChanged);
    _audioCompletionSubscription?.cancel();
    unawaited(_audioController?.dispose());
    super.dispose();
  }

  void _initializeAudioController() {
    final factory =
        widget.audioControllerFactory ??
        AudioplayersPracticeAudioController.new;
    _audioController = factory();
    _audioCompletionSubscription = _audioController!.completionStream.listen((
      _,
    ) {
      if (!mounted) {
        return;
      }
      final l = AppLocalizations.of(context)!;
      setState(() {
        _isPlayingAudio = false;
        _audioMessage = l.practiceAudioPlayedOnce;
      });
    });
  }

  void _onNotifierChanged() {
    if (!mounted) {
      return;
    }
    _notifyTraceIfReady();
    setState(() {});
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

  Future<void> _playCurrentUtterance(CareUtterance utterance) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppLocalizations.of(context)!;
    final controller = _audioController;
    final asset = _audioPlayerAsset(utterance);
    if (controller == null || asset == null || asset.isEmpty) {
      setState(() {
        _audioMessage = l.practiceAudioMissingInline;
      });
      messenger?.showSnackBar(
        SnackBar(content: Text(l.practiceAudioMissingSnack)),
      );
      return;
    }

    setState(() {
      _isPlayingAudio = true;
      _audioMessage = null;
    });
    try {
      await controller.playAsset(asset);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlayingAudio = false;
        _audioMessage = l.practiceAudioUnavailableInline;
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
    final hasPendingStarterPhrasePersistence =
        widget.onRetryStarterPhrasePersistence != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(surfaceTitle),
      ),
      body: SafeArea(
        child: Semantics(
          label: surfaceTitle,
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
                      sortKey: OrdinalSortKey(1),
                      child: _CareTurnPanel(
                        key: const Key('care-turn-current-utterance'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              utterance.english,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              utterance.chinese,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: colors.textPrimary),
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
                              Text(
                                key: const Key('care-turn-audio-error'),
                                _audioMessage!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.textSecondary),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('care-turn-listen-once'),
                              onPressed: _isPlayingAudio
                                  ? null
                                  : () => _playCurrentUtterance(utterance),
                              icon: Icon(
                                _isPlayingAudio
                                    ? Icons.equalizer_rounded
                                    : Icons.volume_up_rounded,
                              ),
                              label: Text(l.practiceListenOnce),
                            ),
                          ),
                          const SizedBox(width: AppLayoutConstants.spacingSm),
                          Expanded(
                            child: FilledButton.icon(
                              key: const Key('care-turn-said-button'),
                              onPressed:
                                  snapshot.phase ==
                                          CareTurnPhase.utteranceReady &&
                                      !hasPendingStarterPhrasePersistence
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
                        !hasPendingStarterPhrasePersistence) ...[
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
                    if (hasPendingStarterPhrasePersistence) ...[
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
    this.onRetryReaction,
    this.onChooseAnotherMoment,
  });

  final String message;
  final CareTurnRetryReaction? onRetryReaction;
  final VoidCallback? onChooseAnotherMoment;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
