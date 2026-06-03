import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:mobile/features/practice/presentation/widgets/practice_bottom_action_bar.dart';
import 'package:mobile/features/practice/presentation/widgets/practice_completion_view.dart';
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
          providerArgs: PracticeSessionProviderArgs(
            routeArgs: args,
            audioControllerFactory: audioControllerFactory,
          ),
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
    required this.providerArgs,
  });

  final PracticeRouteArgs routeArgs;
  final PracticeSessionProviderArgs providerArgs;

  @override
  ConsumerState<_PracticeSessionBody> createState() =>
      _PracticeSessionBodyState();
}

class _PracticeSessionBodyState extends ConsumerState<_PracticeSessionBody> {
  MentorAudioController? _ttsController;
  bool _restoreBannerShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(
        practiceSessionNotifierProvider(widget.providerArgs),
      );
      if (notifier.isDynamic) {
        _ttsController = FlutterTtsMentorAudioController();
      }
      if (notifier.hasPreparedSession) {
        return;
      }
      notifier.ensureSessionReady();
    });
  }

  @override
  void dispose() {
    _ttsController?.dispose();
    super.dispose();
  }

  Future<void> _speakPhrase(String text) async {
    final controller = _ttsController;
    if (controller == null) {
      throw StateError('tts unavailable');
    }
    await controller.speakText(text);
  }

  void _showCoachTip(BuildContext context, String tip) {
    final colors = context.appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          tip,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '知道了',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final notifier = ref.watch(
      practiceSessionNotifierProvider(widget.providerArgs),
    );
    final activity = notifier.activitySnapshot;

    if (notifier.isSessionLoading && activity == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(key: Key('practice-loading')),
          ),
        ),
      );
    }

    if (activity == null) {
      return PracticeFallbackScaffold(
        message:
            notifier.sessionErrorMessage ??
            notifier.homeErrorMessage ??
            l.practiceContextMissing,
      );
    }

    // Show restore banner as SnackBar (once)
    if (!_restoreBannerShown && notifier.restoreStatusMessage != null) {
      _restoreBannerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.restoreStatusMessage!),
            backgroundColor: notifier.hasRecoverableRestoreIssue
                ? colors.warningSoft
                : colors.infoSoft,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    final phrases = activity.phrases;
    final progressValue = phrases.isEmpty
        ? 0.0
        : ((notifier.currentPhraseIndex + 1) / phrases.length).clamp(0.0, 1.0);

    final isComplete = notifier.phrasePhase == PhraseInteractionPhase.complete;
    final phrase = notifier.currentPhrase;
    // Only show reaction chips when explicitly in 'saved' phase.
    // During 'advancing' the index already points to the NEW phrase — show it in 'ready'.
    final cardPhase = notifier.phrasePhase == PhraseInteractionPhase.saved
        ? PhraseCardPhase.saved
        : PhraseCardPhase.ready;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('今日一句'),
      ),
      body: SafeArea(
        child: Semantics(
          label:
              '今日一句，${l.practiceProgress(notifier.currentPhraseIndex + 1, phrases.length)}',
          explicitChildNodes: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutConstants.maxContentWidth,
              ),
              child: Column(
                children: [
                  // ── Progress row (compact) ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayoutConstants.spacingMd,
                      AppLayoutConstants.spacingSm,
                      AppLayoutConstants.spacingMd,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: l.practiceProgress(
                            notifier.currentPhraseIndex + 1,
                            phrases.length,
                          ),
                          value: '${(progressValue * 100).round()}%',
                          child: LinearProgressIndicator(
                            key: const Key('session-progress'),
                            value: progressValue,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(
                              AppLayoutConstants.pillRadius,
                            ),
                            color: colors.textPrimary,
                            backgroundColor: colors.outlineSoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              l.practiceProgress(
                                notifier.currentPhraseIndex + 1,
                                phrases.length,
                              ),
                              key: const Key('practice-progress-text'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                _showCoachTip(context, activity.coachTip);
                              },
                              child: Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ── Scrollable content ────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayoutConstants.spacingLg,
                        AppLayoutConstants.spacingXs,
                        AppLayoutConstants.spacingLg,
                        AppLayoutConstants.spacingLg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Main card / completion view ───────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: isComplete
                                ? PracticeCompletionView(
                                    key: const Key('practice-completion-view'),
                                    spokenCount:
                                        notifier.currentPhraseIndex + 1,
                                    onRestart: () {
                                      ref
                                          .read(
                                            practiceSessionNotifierProvider(
                                                widget.providerArgs),
                                          )
                                          .ensureSessionReady();
                                    },
                                    onExit: () =>
                                        Navigator.of(context).maybePop(),
                                  )
                                : phrase != null
                                    ? PhraseCard(

                                        phrase: phrase,
                                        isActive: true,
                                        isCompleted: notifier.isPhraseCompleted(
                                            phrase.phraseId),
                                        playbackStatus: notifier.playbackStatus,
                                        saveStatus: notifier.saveStatus,
                                        playbackMessage:
                                            notifier.playbackMessage,
                                        saveMessage: notifier.saveMessage,
                                        canPlay: notifier.canPlayCurrentPhrase,
                                        canSubmitReaction:
                                            notifier.canSubmitReaction,
                                        onPlay: notifier.playCurrentPhrase,
                                        isTtsMode: notifier.isDynamic &&
                                            phrase.audioAsset.isEmpty,
                                        onTtsSpeak: (notifier.isDynamic &&
                                                phrase.audioAsset.isEmpty)
                                            ? () =>
                                                notifier.speakCurrentPhrase(
                                                    _speakPhrase)
                                            : null,
                                        phase: cardPhase,
                                        sceneTag: notifier.sceneTag,
                                        onReactionSelected:
                                            (reactionType) async {
                                          AppHaptics.lightTap();
                                          await ref
                                              .read(
                                                practiceSessionNotifierProvider(
                                                    widget.providerArgs),
                                              )
                                              .recordReaction(reactionType);
                                        },
                                      )
                                    : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 60), // bottom bar clearance
                        ],
                      ),
                    ),
                  ),
                  // ── Fixed bottom action bar ───────────────────────────────
                  if (!isComplete)
                    PracticeBottomActionBar(
                      phase: notifier.phrasePhase,
                      nextLoadStatus: notifier.nextPhraseLoadStatus,
                      onSave: () {
                        AppHaptics.lightTap();
                        ref
                            .read(practiceSessionNotifierProvider(
                                widget.providerArgs))
                            .saveCurrentPhrase();
                      },
                      onSkipPhrase: () {
                        AppHaptics.lightTap();
                        ref
                            .read(practiceSessionNotifierProvider(
                                widget.providerArgs))
                            .skipCurrentPhrase();
                      },
                      onEnd: () {
                        ref
                            .read(practiceSessionNotifierProvider(
                                widget.providerArgs))
                            .endSession();
                      },
                      onSkipReaction: () {
                        AppHaptics.lightTap();
                        ref
                            .read(practiceSessionNotifierProvider(
                                widget.providerArgs))
                            .skipToNextPhrase();
                      },
                      onRetryNextPhrase: () {
                        ref
                            .read(practiceSessionNotifierProvider(
                                widget.providerArgs))
                            .skipCurrentPhrase();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
