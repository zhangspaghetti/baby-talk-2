import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

/// Fixed bottom action bar for the V21 practice screen.
///
/// Renders different content based on [phase] and [nextLoadStatus]:
/// - [PhraseInteractionPhase.ready] + idle:  「说完了」+ 「换一句」+「结束」
/// - [PhraseInteractionPhase.ready] + loading: spinner + 「下一句准备中」(disabled)
/// - [PhraseInteractionPhase.ready] + error:   「换一句没准备好，点我重试」+「重试」+「结束」
/// - [PhraseInteractionPhase.saved]:            「跳过，下一句」
/// - [PhraseInteractionPhase.advancing]:        same as ready
/// - [PhraseInteractionPhase.complete]:         hidden (parent switches to CompletionView)
class PracticeBottomActionBar extends StatelessWidget {
  const PracticeBottomActionBar({
    super.key,
    required this.phase,
    required this.nextLoadStatus,
    required this.onSave,
    required this.onSkipPhrase,
    required this.onEnd,
    required this.onSkipReaction,
    required this.onRetryNextPhrase,
  });

  final PhraseInteractionPhase phase;
  final NextPhraseLoadStatus nextLoadStatus;
  final VoidCallback onSave;
  final VoidCallback onSkipPhrase;
  final VoidCallback onEnd;

  /// "跳过，下一句" — skip reaction and advance while in [saved] phase.
  final VoidCallback onSkipReaction;

  /// Retry loading after a [NextPhraseLoadStatus.error].
  final VoidCallback onRetryNextPhrase;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: context.appColors.outlineSoft,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppLayoutConstants.spacingMd,
          AppLayoutConstants.spacingSm,
          AppLayoutConstants.spacingMd,
          AppLayoutConstants.spacingMd,
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (nextLoadStatus == NextPhraseLoadStatus.loading) {
      return _buildLoadingState(context);
    }
    if (nextLoadStatus == NextPhraseLoadStatus.error) {
      return _buildErrorState(context);
    }
    switch (phase) {
      case PhraseInteractionPhase.saved:
        return _buildSavedState(context);
      case PhraseInteractionPhase.advancing:
      case PhraseInteractionPhase.ready:
      case PhraseInteractionPhase.complete:
        return _buildReadyState(context);
    }
  }

  Widget _buildReadyState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppLayoutConstants.minTouchTarget,
          child: FilledButton(
            onPressed: onSave,
            child: const Text('说完了'),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayoutConstants.minTouchTarget,
                  ),
                ),
                onPressed: onSkipPhrase,
                child: const Text('换一句'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayoutConstants.minTouchTarget,
                  ),
                ),
                onPressed: onEnd,
                child: const Text('结束'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavedState(BuildContext context) {
    return SizedBox(
      height: AppLayoutConstants.minTouchTarget,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(
            AppLayoutConstants.minTouchTarget,
          ),
        ),
        onPressed: onSkipReaction,
        child: const Text('跳过，下一句'),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppLayoutConstants.minTouchTarget,
          child: FilledButton(
            onPressed: null, // disabled while loading
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('下一句准备中'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(
              AppLayoutConstants.minTouchTarget,
            ),
          ),
          onPressed: onEnd,
          child: const Text('结束'),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '换一句没准备好，点我重试',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.error,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayoutConstants.minTouchTarget,
                  ),
                ),
                onPressed: onRetryNextPhrase,
                child: const Text('重试'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppLayoutConstants.minTouchTarget,
                  ),
                ),
                onPressed: onEnd,
                child: const Text('结束'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
