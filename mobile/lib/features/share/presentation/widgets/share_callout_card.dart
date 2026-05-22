import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart'
    show ShareViewStatus;
import 'package:mobile/l10n/app_localizations.dart';

/// Accepts either a [ShareNotifier] or [ShareNotifier].
///
/// Both expose the same API surface (currentDraft, isSharing, etc.),
/// so we accept `dynamic` and access properties dynamically.
class ShareCalloutCard extends StatelessWidget {
  const ShareCalloutCard({
    super.key,
    required this.surfaceKeyPrefix,
    required this.notifier,
    required this.sectionLabel,
    required this.emptyMessage,
    this.onShare,
  });

  final String surfaceKeyPrefix;
  final dynamic notifier;
  final String sectionLabel;
  final String emptyMessage;
  final Future<void> Function()? onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final draft = notifier.currentDraft;
    final hasDraft = draft != null;
    final buttonEnabled = hasDraft && !notifier.isSharing && onShare != null;
    final state = _ShareStateSpec.resolve(
      notifier: notifier,
      hasDraft: hasDraft,
      colors: colors,
    );

    return AppSurfaceCard(
      key: Key('$surfaceKeyPrefix-share-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sectionLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(
            draft?.headline ?? l.shareNoContent,
            key: Key('$surfaceKeyPrefix-share-headline'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            draft?.storyText ?? emptyMessage,
            key: Key('$surfaceKeyPrefix-share-body'),
            style: theme.textTheme.bodyMedium,
          ),
          if (draft?.phraseText != null &&
              draft!.phraseText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('$surfaceKeyPrefix-share-phrase-pill'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.englishSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.sharePhraseTodayLabel(draft.phraseText!.trim()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.english,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (draft?.recommendationTitle != null &&
              draft!.recommendationTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              draft.recommendationReason?.trim().isNotEmpty == true
                  ? '${draft.recommendationTitle!.trim()} · ${draft.recommendationReason!.trim()}'
                  : draft.recommendationTitle!.trim(),
              key: Key('$surfaceKeyPrefix-share-recommendation'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _ShareStateBanner(
            key: Key('$surfaceKeyPrefix-share-state-${state.name}'),
            message: state.message,
            backgroundColor: state.backgroundColor,
            foregroundColor: state.foregroundColor,
            showProgress: state.showProgress,
          ),
          const SizedBox(height: 16),
          if (hasDraft) const SizedBox(key: Key('share-cta-marker')),
          if (hasDraft)
            SizedBox(
              key: Key('$surfaceKeyPrefix-share-cta-visible'),
              width: 0,
              height: 0,
            ),
          ElevatedButton(
            key: Key('$surfaceKeyPrefix-share-button'),
            onPressed: !buttonEnabled
                ? null
                : () async {
                    await onShare!();
                  },
            child: Text(
              notifier.isSharing
                  ? l.shareGenerating
                  : hasDraft
                  ? l.shareButton
                  : l.shareWaiting,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStateSpec {
  const _ShareStateSpec({
    required this.name,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.showProgress = false,
  });

  final String name;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showProgress;

  static _ShareStateSpec resolve({
    required dynamic notifier,
    required bool hasDraft,
    required BabyTalkColors colors,
  }) {
    if (notifier.isSharing) {
      return _ShareStateSpec(
        name: 'loading',
        message: '正在生成脱敏分享链接，请稍候。',
        backgroundColor: colors.bgAccentSoft,
        foregroundColor: colors.accentDark,
        showProgress: true,
      );
    }
    if (!hasDraft) {
      return _ShareStateSpec(
        name: 'disabled',
        message: '等最近成长或继续建议整理好后，再生成脱敏分享链接。',
        backgroundColor: colors.bgSunken,
        foregroundColor: colors.textSecondary,
      );
    }

    switch (notifier.lastShareStatus) {
      case ShareViewStatus.success:
        return _ShareStateSpec(
          name: 'success',
          message: notifier.message ?? '分享面板已打开。',
          backgroundColor: colors.successSoft,
          foregroundColor: colors.success,
        );
      case ShareViewStatus.cancelled:
        return _ShareStateSpec(
          name: 'cancelled',
          message: notifier.message ?? '已取消分享。',
          backgroundColor: colors.bgSunken,
          foregroundColor: colors.textSecondary,
        );
      case ShareViewStatus.error:
        return _ShareStateSpec(
          name: 'error',
          message: notifier.message ?? '分享暂时不可用，请稍后重试。',
          backgroundColor: colors.errorSoft,
          foregroundColor: colors.error,
        );
      case ShareViewStatus.idle:
        return _ShareStateSpec(
          name: 'ready',
          message: '分享内容会自动脱敏，只保留适合家人查看的成长片段。',
          backgroundColor: colors.englishSoft,
          foregroundColor: colors.english,
        );
      default:
        return _ShareStateSpec(
          name: 'ready',
          message: '分享内容会自动脱敏，只保留适合家人查看的成长片段。',
          backgroundColor: colors.englishSoft,
          foregroundColor: colors.english,
        );
    }
  }
}

class _ShareStateBanner extends StatelessWidget {
  const _ShareStateBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.showProgress,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProgress) ...[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
