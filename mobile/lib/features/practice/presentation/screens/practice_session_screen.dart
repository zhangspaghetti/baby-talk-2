import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/widgets/activation_frame.dart';
import 'package:mobile/features/practice/presentation/widgets/phrase_card.dart';
import 'package:provider/provider.dart';

class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({super.key});

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<PracticeSessionViewModel>().ensureSessionReady();
    });
  }

  @override
  Widget build(BuildContext context) {
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
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('练习暂不可用'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _PracticeFallback(
              message: viewModel.sessionErrorMessage ?? '当前活动上下文缺失，请返回首页重试。',
            ),
          ),
        ),
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
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                LinearProgressIndicator(
                  key: const Key('session-progress'),
                  value: progressValue,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.accent,
                  backgroundColor: const Color(0xFFD8CFC8),
                ),
                const SizedBox(height: 12),
                Text(
                  '第 ${viewModel.currentPhraseIndex + 1} / ${phrases.length} 句',
                  key: const Key('practice-progress-text'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgAccentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activity.coachTip,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (viewModel.sessionErrorMessage != null) ...[
                  const SizedBox(height: 16),
                  _PracticeBanner(
                    key: const Key('session-error-banner'),
                    message: viewModel.sessionErrorMessage!,
                    backgroundColor: AppTheme.errorSoft,
                    foregroundColor: AppTheme.error,
                  ),
                ],
                if (viewModel.sessionCompleted) ...[
                  const SizedBox(height: 16),
                  _PracticeBanner(
                    key: const Key('practice-complete-banner'),
                    message: '最后一句也已保存，本轮练习已完成。返回首页后会看到最近一次本地结果。',
                    backgroundColor: AppTheme.successSoft,
                    foregroundColor: AppTheme.success,
                  ),
                ],
                const SizedBox(height: 20),
                for (var index = 0; index < phrases.length; index++) ...[
                  if (index == viewModel.currentPhraseIndex)
                    ActivationFrame(
                      stepLabel: 'STEP ${phrases[index].step}',
                      title: '当前练习中的短语',
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

class _PracticeFallback extends StatelessWidget {
  const _PracticeFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('practice-safe-fallback'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回首页'),
          ),
        ],
      ),
    );
  }
}

class _PracticeBanner extends StatelessWidget {
  const _PracticeBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
