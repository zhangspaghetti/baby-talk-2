import 'dart:async';

import 'package:flutter/material.dart';
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

class CareTurnSurface extends StatefulWidget {
  const CareTurnSurface({
    super.key,
    required this.notifier,
    this.audioControllerFactory,
    this.onTraceReady,
    this.onQuietExit,
    this.showQuietExit = true,
  });

  final CarePathNotifier notifier;
  final PracticeAudioController Function()? audioControllerFactory;
  final CareTurnTraceReady? onTraceReady;
  final VoidCallback? onQuietExit;
  final bool showQuietExit;

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
    if (identical(oldWidget.notifier, widget.notifier)) {
      return;
    }
    oldWidget.notifier.removeListener(_onNotifierChanged);
    widget.notifier.addListener(_onNotifierChanged);
    _notifyTraceIfReady();
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
        widget.onTraceReady?.call(snapshot);
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
      return _CareTurnFallbackScaffold(message: message);
    }

    final utterance = snapshot.currentUtterance!;
    final nextSupportUtterance = snapshot.nextSupportUtterance;
    final latestImpact = snapshot.latestGardenImpact;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(l.practiceOneTurnTitle),
      ),
      body: SafeArea(
        child: Semantics(
          label: l.practiceOneTurnTitle,
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
                    _CareTurnPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.moment.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (snapshot.moment.careActionLabel
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              snapshot.moment.careActionLabel,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
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
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    _CareTurnPanel(
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
                          Text(
                            utterance.pronunciation,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          if (_audioMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _audioMessage!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    Row(
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
                                snapshot.phase == CareTurnPhase.utteranceReady
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
                    if (snapshot.phase == CareTurnPhase.reactionPrompt) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _CareTurnPanel(
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
                                await notifier.selectReaction(reactionType);
                              },
                            ),
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
                    if (widget.showQuietExit) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          key: const Key('care-turn-quiet-exit'),
                          onPressed: widget.onQuietExit,
                          child: const Text('先这样就好'),
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
  const _CareTurnFallbackScaffold({required this.message});

  final String message;

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
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
