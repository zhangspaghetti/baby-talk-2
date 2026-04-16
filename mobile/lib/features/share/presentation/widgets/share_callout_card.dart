import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';

class ShareCalloutCard extends StatelessWidget {
  const ShareCalloutCard({
    super.key,
    required this.surfaceKeyPrefix,
    required this.viewModel,
    required this.sectionLabel,
    required this.emptyMessage,
    this.onShare,
  });

  final String surfaceKeyPrefix;
  final ShareViewModel viewModel;
  final String sectionLabel;
  final String emptyMessage;
  final Future<void> Function()? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = viewModel.currentDraft;
    final hasDraft = draft != null;
    final buttonEnabled = hasDraft && !viewModel.isSharing && onShare != null;
    final state = _ShareStateSpec.resolve(viewModel: viewModel, hasDraft: hasDraft);

    return Container(
      key: Key('$surfaceKeyPrefix-share-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
        boxShadow: AppTheme.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sectionLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(
            draft?.headline ?? '当前还没有可分享的成长瞬间',
            key: Key('$surfaceKeyPrefix-share-headline'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            draft?.storyText ?? emptyMessage,
            key: Key('$surfaceKeyPrefix-share-body'),
            style: theme.textTheme.bodyMedium,
          ),
          if (draft?.phraseText != null && draft!.phraseText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('$surfaceKeyPrefix-share-phrase-pill'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.englishSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '今天说的一句：${draft.phraseText!.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.english,
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
                color: AppTheme.textSecondary,
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
              viewModel.isSharing
                  ? '正在生成分享链接…'
                  : hasDraft
                  ? '分享给家人'
                  : '等待可分享内容',
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
    required ShareViewModel viewModel,
    required bool hasDraft,
  }) {
    if (viewModel.isSharing) {
      return const _ShareStateSpec(
        name: 'loading',
        message: '正在生成脱敏分享链接，请稍候。',
        backgroundColor: AppTheme.bgAccentSoft,
        foregroundColor: AppTheme.accentDark,
        showProgress: true,
      );
    }
    if (!hasDraft) {
      return const _ShareStateSpec(
        name: 'disabled',
        message: '等最近成长或继续建议整理好后，再生成脱敏分享链接。',
        backgroundColor: AppTheme.bgSunken,
        foregroundColor: AppTheme.textSecondary,
      );
    }

    switch (viewModel.lastShareStatus) {
      case ShareViewStatus.success:
        return _ShareStateSpec(
          name: 'success',
          message: viewModel.message ?? '分享面板已打开。',
          backgroundColor: AppTheme.successSoft,
          foregroundColor: AppTheme.success,
        );
      case ShareViewStatus.cancelled:
        return _ShareStateSpec(
          name: 'cancelled',
          message: viewModel.message ?? '已取消分享。',
          backgroundColor: AppTheme.bgSunken,
          foregroundColor: AppTheme.textSecondary,
        );
      case ShareViewStatus.error:
        return _ShareStateSpec(
          name: 'error',
          message: viewModel.message ?? '分享暂时不可用，请稍后重试。',
          backgroundColor: AppTheme.errorSoft,
          foregroundColor: AppTheme.error,
        );
      case ShareViewStatus.idle:
        return const _ShareStateSpec(
          name: 'ready',
          message: '分享内容会自动脱敏，不包含昵称、安装号或调试信息。',
          backgroundColor: AppTheme.englishSoft,
          foregroundColor: AppTheme.english,
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
