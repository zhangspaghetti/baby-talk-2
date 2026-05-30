import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_celebration_overlay.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/activation_frame.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Scene-specific dynamic mentor copy for the practice page (V21).
String _sceneMentorCopy(String? sceneTag) {
  switch (sceneTag) {
    case 'feeding':
      return '喂饭时轻轻说，宝宝会听的。';
    case 'drinking':
      return '递水的时候说一句就好。';
    case 'diaper':
      return '换尿布时说，宝宝反而更安静。';
    case 'bath':
      return '洗澡时说，宝宝会觉得好玩。';
    case 'bedtime':
      return '睡前轻轻说，像讲故事一样。';
    case 'going_out':
      return '出门前说一句，今天就开始了。';
    default:
      return '会说就直接说。';
  }
}

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

    final phrases = activity.phrases;
    final progressValue = phrases.isEmpty
        ? 0.0
        : ((notifier.currentPhraseIndex + 1) / phrases.length).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(activity.title),
      ),
      body: SafeArea(
        child: Semantics(
          label:
              '${activity.title}，${l.practiceProgress(notifier.currentPhraseIndex + 1, phrases.length)}',
          explicitChildNodes: true,
          child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: AppLayoutConstants.practicePadding,
              children: [
                const SizedBox(height: 4),
                Semantics(
                  label: l.practiceProgress(
                    notifier.currentPhraseIndex + 1,
                    phrases.length,
                  ),
                  value: '${(progressValue * 100).round()}%',
                  child: LinearProgressIndicator(
                    key: const Key('session-progress'),
                    value: progressValue,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
                    color: colors.textPrimary,
                    backgroundColor: colors.outlineSoft,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.practiceProgress(
                    notifier.currentPhraseIndex + 1,
                    phrases.length,
                  ),
                  key: const Key('practice-progress-text'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                // Xiaohe dynamic scene copy (V21)
                AppMentorBubble(
                  message: _sceneMentorCopy(notifier.sceneTag),
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: '提示，${activity.coachTip}',
                  child: AppSurfaceCard(
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.bgSurface,
                    borderRadius: AppLayoutConstants.cardRadius,
                    borderColor: Colors.transparent,
                    boxShadow: const [],
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        key: const Key('practice-coach-tip'),
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppLayoutConstants.spacingMd,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppLayoutConstants.spacingMd,
                          0,
                          AppLayoutConstants.spacingMd,
                          AppLayoutConstants.spacingMd,
                        ),
                        minTileHeight: AppLayoutConstants.minTouchTarget,
                        title: Text(
                          '提示',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: colors.textPrimary),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              activity.coachTip,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (notifier.restoreStatusMessage != null) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('practice-restore-banner'),
                    message: notifier.restoreStatusMessage!,
                    backgroundColor: notifier.hasRecoverableRestoreIssue
                        ? colors.warningSoft
                        : colors.infoSoft,
                    foregroundColor: colors.textPrimary,
                  ),
                ],
                if (notifier.sessionErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('session-error-banner'),
                    message: notifier.sessionErrorMessage!,
                    backgroundColor: colors.errorSoft,
                    foregroundColor: colors.textPrimary,
                  ),
                ],
                if (notifier.sessionCompleted) ...[
                  const SizedBox(height: 16),
                  AppCelebrationOverlay(
                    key: const Key('practice-celebration-overlay'),
                    child: AppBanner(
                      key: const Key('practice-complete-banner'),
                      message: l.practiceLastSaved,
                      backgroundColor: colors.successSoft,
                      foregroundColor: colors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                for (var index = 0; index < phrases.length; index++) ...[
                  if (index == notifier.currentPhraseIndex)
                    ActivationFrame(
                      stepLabel: l.practicePhraseStep(phrases[index].step),
                      title: l.practiceCurrentPhrases,
                      child: PhraseCard(
                        phrase: phrases[index],
                        isActive: true,
                        isCompleted: notifier.isPhraseCompleted(
                          phrases[index].phraseId,
                        ),
                        playbackStatus: notifier.playbackStatus,
                        saveStatus: notifier.saveStatus,
                        playbackMessage: notifier.playbackMessage,
                        saveMessage: notifier.saveMessage,
                        canPlay: notifier.canPlayCurrentPhrase,
                        canSubmitReaction: notifier.canSubmitReaction,
                        onPlay: notifier.playCurrentPhrase,
                        isTtsMode:
                            notifier.isDynamic &&
                            phrases[index].audioAsset.isEmpty,
                        onTtsSpeak:
                            (notifier.isDynamic &&
                                phrases[index].audioAsset.isEmpty)
                            ? () => notifier.speakCurrentPhrase(_speakPhrase)
                            : null,
                        onReactionSelected: (reactionType) async {
                          AppHaptics.lightTap();
                          final navigator = Navigator.of(context);
                          final outcome = await ref
                              .read(
                                practiceSessionNotifierProvider(
                                  widget.providerArgs,
                                ),
                              )
                              .recordReaction(reactionType);
                          if (!mounted) {
                            return;
                          }
                          if (outcome == PracticeRecordOutcome.completed &&
                              navigator.canPop()) {
                            // V21: extend auto-advance to 2.5-3s for onboarding feel
                            await Future<void>.delayed(
                              const Duration(milliseconds: 2700),
                            );
                            if (!mounted || !navigator.canPop()) {
                              return;
                            }
                            navigator.pop();
                          }
                        },
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PhraseCard(
                        phrase: phrases[index],
                        isActive: false,
                        isCompleted: notifier.isPhraseCompleted(
                          phrases[index].phraseId,
                        ),
                        playbackStatus: PracticePlaybackStatus.idle,
                        saveStatus: PracticeSaveStatus.idle,
                        playbackMessage: null,
                        saveMessage: null,
                        canPlay: false,
                        canSubmitReaction: false,
                        onPlay: null,
                        onReactionSelected: null,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
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
