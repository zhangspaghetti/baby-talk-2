import 'package:flutter/material.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/widgets/activation_frame.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

class PracticeSessionScreen extends StatelessWidget {
  const PracticeSessionScreen({
    super.key,
    required this.routeEntry,
    this.audioControllerFactory,
  });

  final PracticeRouteEntry routeEntry;
  final PracticeAudioController Function()? audioControllerFactory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!routeEntry.hasValidArgs) {
      return PracticeFallbackScaffold(
        message: routeEntry.errorMessage ?? l.practiceInvalidParams,
      );
    }

    final args = routeEntry.args!;
    final repository = context.read<PracticeRepository>();
    final accountViewModel = context.read<AccountViewModel?>();
    return ChangeNotifierProvider<PracticeSessionViewModel>(
      create: (_) => PracticeSessionViewModel(
        repository: repository,
        spaceId: args.spaceId,
        activityId: args.activityId,
        accessTokenLoader: () =>
            accountViewModel?.snapshot.session?.accessToken,
        audioController: audioControllerFactory?.call(),
      )..initialize(),
      child: _PracticeSessionBody(routeArgs: args),
    );
  }
}

class _PracticeSessionBody extends StatefulWidget {
  const _PracticeSessionBody({required this.routeArgs});

  final PracticeRouteArgs routeArgs;

  @override
  State<_PracticeSessionBody> createState() => _PracticeSessionBodyState();
}

class _PracticeSessionBodyState extends State<_PracticeSessionBody> {
  MentorAudioController? _ttsController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final viewModel = context.read<PracticeSessionViewModel>();
      if (viewModel.isDynamic) {
        _ttsController = FlutterTtsMentorAudioController();
      }
      if (viewModel.hasPreparedSession) {
        return;
      }
      viewModel.ensureSessionReady();
    });
  }

  @override
  void dispose() {
    _ttsController?.dispose();
    super.dispose();
  }

  Future<void> _speakPhrase(String text) async {
    final controller = _ttsController;
    if (controller == null) return;
    try {
      await controller.speakText(text);
    } catch (_) {
      // TTS 失败静默处理
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final viewModel = context.watch<PracticeSessionViewModel>();
    final activity = viewModel.activitySnapshot;

    if (viewModel.isSessionLoading && activity == null) {
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
            viewModel.sessionErrorMessage ??
            viewModel.homeErrorMessage ??
            l.practiceContextMissing,
      );
    }

    final phrases = activity.phrases;
    final progressValue = phrases.isEmpty
        ? 0.0
        : ((viewModel.currentPhraseIndex + 1) / phrases.length).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(activity.title),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  key: Key(
                    'practice-route-scope-${widget.routeArgs.spaceId}-${widget.routeArgs.activityId}',
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.bgSunken,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'route scope · ${widget.routeArgs.scopeLabel}',
                    key: const Key('practice-route-scope'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  key: const Key('session-progress'),
                  value: progressValue,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(999),
                  color: colors.accent,
                  backgroundColor: colors.outlineSoft,
                ),
                const SizedBox(height: 12),
                Text(
                  '第 ${viewModel.currentPhraseIndex + 1} / ${phrases.length} 句',
                  key: const Key('practice-progress-text'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.bgAccentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activity.coachTip,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (viewModel.restoreStatusMessage != null) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('practice-restore-banner'),
                    message: viewModel.restoreStatusMessage!,
                    backgroundColor: viewModel.hasRecoverableRestoreIssue
                        ? colors.warningSoft
                        : colors.infoSoft,
                    foregroundColor: viewModel.hasRecoverableRestoreIssue
                        ? colors.warning
                        : colors.info,
                  ),
                ],
                if (viewModel.sessionErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('session-error-banner'),
                    message: viewModel.sessionErrorMessage!,
                    backgroundColor: colors.errorSoft,
                    foregroundColor: colors.error,
                  ),
                ],
                if (viewModel.sessionCompleted) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('practice-complete-banner'),
                    message: l.practiceLastSaved,
                    backgroundColor: colors.successSoft,
                    foregroundColor: colors.success,
                  ),
                ],
                const SizedBox(height: 20),
                for (var index = 0; index < phrases.length; index++) ...[
                  if (index == viewModel.currentPhraseIndex)
                    ActivationFrame(
                      stepLabel: 'STEP ${phrases[index].step}',
                      title: l.practiceCurrentPhrases,
                      child: PhraseCard(
                        phrase: phrases[index],
                        isActive: true,
                        isCompleted: viewModel.isPhraseCompleted(
                          phrases[index].phraseId,
                        ),
                        playbackStatus: viewModel.playbackStatus,
                        saveStatus: viewModel.saveStatus,
                        playbackMessage: viewModel.playbackMessage,
                        saveMessage: viewModel.saveMessage,
                        canPlay: viewModel.canPlayCurrentPhrase,
                        canSubmitReaction: viewModel.canSubmitReaction,
                        onPlay: viewModel.playCurrentPhrase,
                        isTtsMode:
                            viewModel.isDynamic &&
                            phrases[index].audioAsset.isEmpty,
                        onTtsSpeak:
                            (viewModel.isDynamic &&
                                phrases[index].audioAsset.isEmpty)
                            ? () => _speakPhrase(phrases[index].english)
                            : null,
                        onReactionSelected: (reactionType) async {
                          final navigator = Navigator.of(context);
                          final outcome = await context
                              .read<PracticeSessionViewModel>()
                              .recordReaction(reactionType);
                          if (!mounted) {
                            return;
                          }
                          if (outcome == PracticeRecordOutcome.completed &&
                              navigator.canPop()) {
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
                        isCompleted: viewModel.isPhraseCompleted(
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
