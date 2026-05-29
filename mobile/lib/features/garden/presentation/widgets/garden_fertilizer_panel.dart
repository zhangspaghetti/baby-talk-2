import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

/// Garden V2 fertilizer panel: flower visualization + progress + backpack
/// (施肥) + practice-trace claim list (待领取 / 已领取).
class GardenFertilizerPanel extends ConsumerWidget {
  const GardenFertilizerPanel({super.key});

  static const int _maxClaimedShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final notifier = ref.watch(gardenFertilizerNotifierProvider);
    final view = notifier.view;

    if (view.isLoading) {
      return Padding(
        key: const Key('garden-fertilizer-loading'),
        padding: const EdgeInsets.only(bottom: AppLayoutConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            AppShimmer(height: 140),
            SizedBox(height: AppLayoutConstants.spacingSm),
            AppShimmer(height: 64),
          ],
        ),
      );
    }

    final stageInfo = view.stageInfo!;

    return Container(
      key: const Key('garden-fertilizer-panel'),
      margin: const EdgeInsets.only(bottom: AppLayoutConstants.spacingMd),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FlowerVisual(stageInfo: stageInfo, colors: colors),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          _BackpackRow(
            colors: colors,
            backpackCount: view.backpackCount,
            canApply: view.canApply,
            onApply: () {
              AppHaptics.lightTap();
              notifier.apply();
            },
          ),
          if (view.isEmpty)
            Padding(
              key: const Key('garden-fertilizer-empty'),
              padding: const EdgeInsets.only(
                top: AppLayoutConstants.spacingMd,
              ),
              child: Text(
                '还没有肥料，去说一句英文吧。',
                style: TextStyle(color: colors.textMuted, fontSize: 14),
              ),
            )
          else ...[
            const SizedBox(height: AppLayoutConstants.spacingLg),
            _SourceListHeader(colors: colors),
            const SizedBox(height: AppLayoutConstants.spacingSm),
            for (final pack in view.pendingPacks)
              _PendingPackTile(
                key: Key('garden-fertilizer-pending-${pack.eventKey}'),
                pack: pack,
                colors: colors,
                onClaim: () {
                  AppHaptics.lightTap();
                  notifier.claim(pack.eventKey);
                },
              ),
            for (final pack in view.claimedPacks.take(_maxClaimedShown))
              _ClaimedPackTile(pack: pack, colors: colors),
          ],
        ],
      ),
    );
  }
}

class _FlowerVisual extends StatelessWidget {
  const _FlowerVisual({required this.stageInfo, required this.colors});

  final FertilizerStageInfo stageInfo;
  final BabyTalkColors colors;

  String get _glyph {
    switch (stageInfo.stage) {
      case FertilizerFlowerStage.seed:
        return '🌰';
      case FertilizerFlowerStage.sprout:
        return '🌱';
      case FertilizerFlowerStage.budding:
        return '🌿';
      case FertilizerFlowerStage.blooming:
        return '🌸';
      case FertilizerFlowerStage.fruiting:
        return '🍎';
    }
  }

  String get _progressHint {
    if (stageInfo.isFinalStage) {
      return '已经长到最后阶段，可以回来复习加深熟悉感。';
    }
    return '再施肥 ${stageInfo.appliesToNext} 次就到「${stageInfo.nextStage!.label}」了';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text(_glyph, style: const TextStyle(fontSize: 56))),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        Text(
          stageInfo.stage.label,
          key: const Key('garden-fertilizer-stage-label'),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stageInfo.stage.warmSummary,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
          child: LinearProgressIndicator(
            key: const Key('garden-fertilizer-progress'),
            value: stageInfo.progressToNext,
            minHeight: 8,
            backgroundColor: colors.bgSunken,
            valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '已施肥 ${stageInfo.appliedCount} 次 · $_progressHint',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _BackpackRow extends StatelessWidget {
  const _BackpackRow({
    required this.colors,
    required this.backpackCount,
    required this.canApply,
    required this.onApply,
  });

  final BabyTalkColors colors;
  final int backpackCount;
  final bool canApply;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.eco_rounded, size: 20, color: colors.success),
        const SizedBox(width: AppLayoutConstants.spacingSm),
        Expanded(
          child: Text(
            '你有 $backpackCount 包肥料',
            key: const Key('garden-fertilizer-backpack-count'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          key: const Key('garden-fertilizer-apply-button'),
          onPressed: canApply ? onApply : null,
          child: const Text('施肥'),
        ),
      ],
    );
  }
}

class _SourceListHeader extends StatelessWidget {
  const _SourceListHeader({required this.colors});

  final BabyTalkColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      '肥料来源',
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PendingPackTile extends StatelessWidget {
  const _PendingPackTile({
    super.key,
    required this.pack,
    required this.colors,
    required this.onClaim,
  });

  final FertilizerPack pack;
  final BabyTalkColors colors;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppLayoutConstants.spacingSm),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingSm),
      decoration: BoxDecoration(
        color: colors.bgBase,
        borderRadius: BorderRadius.circular(AppLayoutConstants.smallRadius),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pack.detail} · ${_formatTime(pack.occurredAt)}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppLayoutConstants.spacingSm),
          OutlinedButton(onPressed: onClaim, child: const Text('领取')),
        ],
      ),
    );
  }
}

class _ClaimedPackTile extends StatelessWidget {
  const _ClaimedPackTile({required this.pack, required this.colors});

  final FertilizerPack pack;
  final BabyTalkColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayoutConstants.spacingXs),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: colors.textMuted),
          const SizedBox(width: AppLayoutConstants.spacingSm),
          Expanded(
            child: Text(
              '${pack.title} · 已领取',
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
}
