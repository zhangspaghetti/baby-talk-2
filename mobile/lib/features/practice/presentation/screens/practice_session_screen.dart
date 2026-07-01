import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';
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
        message: routeEntry.errorMessage ?? l.practiceInvalidParams,
      );
    }

    final args = routeEntry.args!;
    final repositoryValue = ref.watch(practiceRepositoryProvider);
    return repositoryValue.when(
      data: (_) {
        return _PracticeSessionBody(
          routeArgs: args,
          audioControllerFactory: audioControllerFactory,
        );
      },
      loading: () => const _PracticeLoadingScaffold(),
      error: (error, stackTrace) =>
          PracticeFallbackScaffold(message: l.homePracticeUnavailable),
    );
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
    required this.routeArgs,
    required this.audioControllerFactory,
  });

  final PracticeRouteArgs routeArgs;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  ConsumerState<_PracticeSessionBody> createState() =>
      _PracticeSessionBodyState();
}

class _PracticeSessionBodyState extends ConsumerState<_PracticeSessionBody> {
  PracticeAudioController? _audioController;
  StreamSubscription<void>? _audioCompletionSubscription;
  String? _requestedMomentKey;
  String? _completedMomentKey;
  int _startGeneration = 0;
  bool _isPlayingAudio = false;
  String? _audioMessage;

  @override
  void initState() {
    super.initState();
    _initializeAudioController();
    _scheduleStartMoment();
  }

  @override
  void didUpdateWidget(covariant _PracticeSessionBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeScopeKey(oldWidget.routeArgs) ==
        _routeScopeKey(widget.routeArgs)) {
      return;
    }
    _scheduleStartMoment();
  }

  @override
  void dispose() {
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

  String _routeScopeKey(PracticeRouteArgs routeArgs) {
    final normalized = routeArgs.normalized();
    return '${normalized.normalizedSpaceId}/${normalized.normalizedActivityId}';
  }

  void _scheduleStartMoment() {
    final normalized = widget.routeArgs.normalized();
    final scopeKey = _routeScopeKey(widget.routeArgs);
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
      final future = ref
          .read(carePathNotifierProvider)
          .startMoment(
            spaceId: normalized.normalizedSpaceId,
            activityId: normalized.normalizedActivityId,
          );
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

  Future<void> _playCurrentUtterance(CareUtterance utterance) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context)!;
    final controller = _audioController;
    final asset = _audioPlayerAsset(utterance);
    if (controller == null || asset == null || asset.isEmpty) {
      setState(() {
        _audioMessage = l.practiceAudioMissingInline;
      });
      messenger.showSnackBar(
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
      messenger.showSnackBar(
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
    final notifier = ref.watch(carePathNotifierProvider);
    final snapshot = notifier.snapshot;
    final normalizedArgs = widget.routeArgs.normalized();
    final scopeKey = _routeScopeKey(widget.routeArgs);
    final hasMatchingSnapshot =
        snapshot?.moment.spaceId == normalizedArgs.normalizedSpaceId &&
        snapshot?.moment.activityId == normalizedArgs.normalizedActivityId;
    final effectiveMessage =
        snapshot?.message ?? notifier.message ?? l.practiceContextMissing;

    if (!hasMatchingSnapshot ||
        snapshot == null ||
        _completedMomentKey != scopeKey ||
        notifier.phase == CareTurnPhase.idle ||
        notifier.phase == CareTurnPhase.loading) {
      return const _PracticeLoadingScaffold();
    }
    if (notifier.phase == CareTurnPhase.error) {
      return PracticeFallbackScaffold(message: effectiveMessage);
    }

    final utterance = snapshot.currentUtterance;
    if (utterance == null) {
      return PracticeFallbackScaffold(message: effectiveMessage);
    }

    final nextSupportUtterance = snapshot.nextSupportUtterance;
    final latestImpact = snapshot.latestGardenImpact;
    final canListen = !_isPlayingAudio;

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
                    _PracticePanel(
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
                    _PracticePanel(
                      key: const Key('practice-current-utterance'),
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
                            key: const Key('practice-listen-once'),
                            onPressed: canListen
                                ? () => _playCurrentUtterance(utterance)
                                : null,
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
                            key: const Key('practice-said-button'),
                            onPressed:
                                snapshot.phase == CareTurnPhase.utteranceReady
                                ? () {
                                    AppHaptics.lightTap();
                                    ref
                                        .read(carePathNotifierProvider)
                                        .markSaid();
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
                      _PracticePanel(
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
                              onSelected: (reactionType) async {
                                AppHaptics.lightTap();
                                await ref
                                    .read(carePathNotifierProvider)
                                    .selectReaction(reactionType);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (nextSupportUtterance != null &&
                        snapshot.phase == CareTurnPhase.nextSupportReady) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _PracticePanel(
                        key: const Key('practice-next-support'),
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
                      _PracticePanel(
                        key: const Key('practice-quiet-fallback'),
                        child: Text(
                          snapshot.message ?? l.practiceQuietFallback,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    ],
                    if (latestImpact != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _PracticePanel(
                        key: const Key('practice-garden-trace'),
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

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({super.key, required this.child});

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
